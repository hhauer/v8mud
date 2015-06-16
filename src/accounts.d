
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.array;
import std.conv;
import std.md5;
import std.string;
import std.file;
import std.xml;

import stringutilities;
import interpreter;
import network;
import propertylist;
import mudobject;
import editor;
import world;
import cmd;
import item;

// GLOBALS
cAccountManager GlobalAccountManager;

class cAccount : cMudObject
{
	this()
	{
		Location = new cLocation;
		Inventory = new cItemList;
	}
	int Load(string FileName)
	{
		string flagkey;
		string flagvalue;

		string s= cast(string)std.file.read(FileName);
		check(s);

		auto base = new DocumentParser(s);
		super.Load(base);
		base.onStartTag["FlagList"]=(ElementParser flaglist)
		{
			flaglist.onStartTag["Flag"]=(ElementParser flag)
			{
				flag.onEndTag["name"]=(in Element e)
				{
					flagkey = e.text;
				};
				flag.onEndTag["value"] = (in Element e)
				{
					flagvalue = e.text;
				};
				flag.parse();
				if(flagvalue == "true")
				{
					Flags[flagkey] = true;
				}
				else
				{
					Flags[flagkey] = false;
				}
			};
			flaglist.parse();
		};
		base.onStartTag["Location"] = &Location.Load;
		base.onStartTag["ItemList"] = &Inventory.Load;
		base.parse();
		return 1;
	};
	int Save(string FileName)
	{
		auto doc = new Document(new Tag("Account"));
		super.Save(doc);

		auto flaglist = new Element("FlagList");
		if(Flags.length > 0)
		{
			foreach(Key; Flags.keys)
			{
				auto flag = new Element("Flag");
				flag ~= new Element("name",Key);
				if(Flags[Key])
				{
					flag ~= new Element("value","true");
				}
				else
				{
					flag ~= new Element("value","false");
				}
				flaglist ~= flag;
			}
		}
		doc ~= flaglist;

		doc ~= Location.Save();
		doc ~= Inventory.Save();
		std.file.write(FileName,doc.prolog ~ "\r\n" ~ join(doc.pretty(4),"\r\n") ~"\r\n");
		return 1;
	};

	void LoadAccount(ElementParser element)
	{
		element.onEndTag["Name"]=(in Element e)
		{
			_Name = e.text;
		};
		element.onEndTag["File"]=(in Element e)
		{
			_AccountFile = e.text;
		};
		element.onEndTag["Password"]=(in Element e)
		{
			_AccountPassword = e.text;
		};
		element.parse();
	};

	Element SaveAccount()
	{
		Element element = new Element("Account");
		element ~= new Element("Name",_Name);
		element ~= new Element("File",_AccountFile);
		element ~= new Element("Password",_AccountPassword);
		return element;
	};

	void SetPassword(string new_password)
	{
		_AccountPassword = getDigestString(new_password);
	}

	bool isPassword(string password)
	{
		if (_AccountPassword == getDigestString(password))
			return true;
		else
			return false;
	}

	bool GetFlag(string Flag)
	{
		if(Flags.length >0)
		{
			Flag = tolower(Flag);
			return Flags[Flag];
		}
		return false;
	};
	void SetFlag(string Flag, bool value)
	{
		Flag = tolower(Flag);
		Flags[Flag] = value;
	};

	bool [string] Flags;

	cClient Client;
	cEditor Editor;
	string State;
	string _AccountFile;
	cLocation Location;
	cItemList Inventory;

private:
	string _AccountPassword;
}

class cAccountManager
{
	cAccount[] AccountList;
	cAccount[] ActiveAccountList;

	string _AccountDir;

	this()
	{
	}
	~this()
	{
	}

	int LoadAccountList(string FileName)
	{
		cAccount Account;
		if(exists(FileName))
		{
			string File = cast(string)std.file.read(FileName);
			check(File);
			auto xml = new DocumentParser(File);
			xml.onStartTag["Account"] = (ElementParser e)
			{
				Account = new cAccount;
				Account.LoadAccount(e);
				AccountList ~= Account;
			};
			xml.parse();
			return 1;
		}
		writeln("\tAccount Manager - AccountList not found ",FileName);
		return 0;
	}
	int NewAccountList(string FileName)
	{
		auto doc = new Document(new Tag("AccountList"));
		std.file.write(FileName,doc.prolog~"\r\n"~join(doc.pretty(4),"\r\n")~"\r\n");
		return 1;
	}
	int SaveAccountList(string FileName)
	{
		auto doc = new Document(new Tag("AccountList"));
		if(AccountList.length > 0)
		{
			foreach(Account; AccountList)
			{
				auto element = Account.SaveAccount();
				doc ~= element;
			}
		}
		std.file.write(FileName, doc.prolog~"\r\n"~join(doc.pretty(4),"\r\n")~"\r\n");
		return 1;
	}

	int Configure(cPropertyList Config)
	{
		if(Config !is null)
		{
			_AccountDir = Config.Get("accounts_dir");
			if(_AccountDir is null)
			{
				_AccountDir = "accounts";
				Config.Set("accounts_dir",_AccountDir);
			}
		}
		return 1;
	};
	int Startup()
	{
		writeln("\t\tchecking Acount Directory");
		if(exists(_AccountDir))
		{
			writeln("\t\tLoading Account List");
			if(LoadAccountList(_AccountDir~"/"~"accounts.xml")==0)
			{
				writeln("\t\t\tCouldn't find account list creating new one");
				NewAccountList(_AccountDir~"/"~"accounts.xml");
			}
		}
		else
		{
			writeln("\t\t\tCreating new Account Dir");
			mkdirRecurse(_AccountDir);
			NewAccountList(_AccountDir~"/"~"accounts.xml");
		}
		return 1;
	};

	int Frame()
	{
		string Input;
		string Retry;
		cClient Client;
		int tries;

		cAccount[] TempList;
		foreach(cAccount Account; ActiveAccountList)
		{
			if(Account !is null)
			{
				Client = Account.Client;
				if(Client.State == "DEAD PASS")
				{
					Account.State = "CLIENT DEAD";
				}
				switch(Account.State)
				{
				case "CLIENT DEAD":
				{
					if(Account.Location.Validate())
					{
						Account.Location.Room.RemAccount(Account._Name);
					}
					Client.State = "DEAD";
					Account.State = "DEAD";
					writeln("\tAccount Client - Dead ");
				}
				break;
				case "ACCOUNT NEW":
				{
					Client.Send("{xIs this the Correct Account Name (({GY{x)es/({RN{x)o) :> ");
					Account.State="ACCOUNT NEW PROMPT";
				}
				break;
				case "ACCOUNT NEW PROMPT":
				{
					if(Client.Lines()  > 0)
					{
						Input = Client.GetLine();
						Input = ToLower(Input);

						if(Input == "y" || Input == "yes")
						{
							Account.State = "ACCOUNT NEW PASSWORD";
						}
						else
						{
							Account.State = "LOGON PROMPT";
						}
					}
				}
				break;
				case "ACCOUNT NEW PASSWORD":
				{
					Client.Send("{xPlease Enter Your New Password:{*{p");
					Account.State = "ACCOUNT NEW PASSWORD PROMPT";
				}
				break;
				case "ACCOUNT NEW PASSWORD PROMPT":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						Account.SetPassword(Input);
						Client.Send("{xRetype Password:>{*{p");
						Account.State = "ACCOUNT NEW PASSWORD VERIFY";
					}
				}
				break;
				case "ACCOUNT NEW PASSWORD VERIFY":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						if(Account.isPassword(Input))
						{
							Account.State = "NEWS";
							Account._AccountFile = _AccountDir ~ "/" ~ Account._Name ~ ".xml";

							if(AccountList.length == 0)
							{
								Account.SetFlag("admin",true);
							}

							writeln("\t\tTry Account Location default@default");
							Account.Location = GlobalWorld.GetLocation("default@default");
							if(Account.Location !is null)
							{
								writeln("\t\tWorked");
							}
							else
							{
								writeln("\t\tFailed");
							}

							Account.Save(Account._AccountFile);
							AccountList ~= Account;
							SaveAccountList(_AccountDir ~ "/" ~ "accounts.xml");
						}
						else
						{
							Account.State = "ACCOUNT NEW PASSWORD";
						}
					}
				}
				break;
				case "ACCOUNT PASSWORD":
				{
					Client.Send("{xPassword:> {*{p");
					Account.State = "ACCOUNT PASSWORD PROMPT";
				}
				break;
				case "ACCOUNT PASSWORD PROMPT":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						if(Account.isPassword(Input))
						{
							Account.State = "NEWS";
							if(Account._AccountFile.length > 0)
							{
								Account.Load(Account._AccountFile);
							}
						}
						else
						{
							Account.State = "ACCOUNT PASSWORD RETRY";
							Account.PropertyList.Set("account_retry", "3");
							Client.Send("{x{rIncorrect Password{n{wPassword:> {*{p");
						}
					}
				}
				break;
				case "ACCOUNT PASSWORD RETRY":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						Retry = Account.PropertyList.Get("account_retry");
						if(Retry !is null)
						{
							tries = to !int(Retry);
							writeln("\tPassword retry, Account",Account._Name," Tries left ", tries);
							if(tries > 0)
							{
								if(Account.isPassword(Input))
								{
									Account.State = "NEWS";
									if(Account._AccountFile.length > 0)
									{
										Account.Load(Account._AccountFile);
									}
								}
								else
								{
									Client.Send("{xIncorrect Password\n\rPassword:> ");
									tries = tries - 1;
									Account.PropertyList.Set("account_retry",to !string(tries));
								}
							}
							else
							{
								Account.State = "DEAD";
							}
						}
					}
				}
				break;
				case "NEWS":
				{
					Account.Client.Send("{n{xNEWS{n");
					Account.Client.Send("{nnews goes here - so put some thing interesting here{n");
					Account.Client.Send("{n[Press Enter to Continue]{n");
					Account.State = "NEWS-PROMPT";
				}
				break;
				case "NEWS-PROMPT":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						Account.State ="CONNECTED";
						if(Account.Location.Validate())
						{
							Account.Location.Room.AddAccount(Account);
							GlobalWorld.Send("{x{n"~Account._Name~"{x has joined the world{n");
						}
						cmd_look(Account,["look"]);
						Account.Client.Send("{x{n:> ");
					}
				}
				case "CONNECTED":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						if(GlobalInterpreter.ExecuteCommand(Account,Input)==1)
						{
							Client.Send("{x{n:> ");
						}
					}
				}
				break;
				case "EDITING":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						if(Account.Editor !is null)
						{
							if(Account.Editor.Edit(Account,Input)==0)
							{
								delete Account.Editor;
								Account.Editor = null;
								Account.State = "CONNECTED";
								Client.Send("{x{n:> ");
							}
							else
							{
								Client.Send("{x{n{GEditor{x:> ");
							}
						}
					}
				}
				break;
				}
			}
			if(Account.State == "DEAD")
			{
				if(Account._AccountFile.length > 0)
				{
					GlobalWorld.Send("{x{n"~Account._Name~"{x has left the world{n");
					Account.Save(Account._AccountFile);
				}
				Client.State = "DEAD";
			}
			else if(Account.State == "LOGON PROMPT")
			{
				Client.State = "LOGON";
			}
			else
			{
				TempList ~= Account;
			}
		}

		ActiveAccountList = TempList;
		return 0;
	};

	int Shutdown()
	{
		writeln("\tsaveing accountlist");
		SaveAccountList(_AccountDir ~ "/" ~ "accounts.xml");
		writeln("\tsaving active accounts");
		if(ActiveAccountList.length > 0)
		{
			foreach(cAccount Account; ActiveAccountList)
			{
				if(Account !is null)
				{
					if(Account._AccountFile.length > 0)
					{
						writeln("\t\tSaving Account ", Account._Name," ", Account._AccountFile);
						Account.Save(Account._AccountFile);
					}
				}
			}
		}
		return 0;
	};

	cAccount GetAccount(string AccountName)
	{
		if(AccountList.length > 0)
		{
			foreach(Account; AccountList)
			{
				if(Account !is null)
				{
					if(Account._Name == AccountName)
						return Account;
				}
			}
		}
		return null;
	};

	int RemAccount(string AccountName)
	{
		cAccount [] TempList;
		if(AccountList.length > 0)
		{
			foreach(Account; AccountList)
			{
				if(Account._Name != AccountName)
				{
					TempList ~= Account;
				}
			}
			AccountList = TempList;
		}
		return 0;
	};

	bool isAccountActive(string AccountName)
	{
		if(ActiveAccountList.length > 0)
		{
			foreach(Account; ActiveAccountList)
			{
				if(Account._Name == AccountName)
				{
					return true;
				}
			}
		}
		return false;
	};

	bool isAccount(string AccountName)
	{
		if(AccountList.length > 0 )
		{
			foreach(Account; AccountList)
			{
				if(Account._Name == AccountName)
				{
					return true;
				}
			}
		}
		return false;
	};

	cAccount GetActiveAccount(string AccountName)
	{

		if(ActiveAccountList.length > 0)
		{
			foreach(Account ; ActiveAccountList)
			{
				if(Account._Name == AccountName)
				{
					return Account;
				}
			}
		}
		return null;
	};
}

