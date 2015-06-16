
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.string;
import std.conv;

import accounts;
import stringutilities;
import cmd;
import cmd_admin;
import cmd_olc;
import world;

// GLOBALS
cInterpreter GlobalInterpreter;

class cCommand
{
	int function(cAccount, string[]) _fp;

	string _Name;
	string _Use;
	bool[string] _Flags;
};

class cInterpreter
{
	cCommand[] CommandList;
	int AddCommand(string CommandName,string [] flags,int function(cAccount, string []) fp, string Use)
	{
		cCommand Command = new cCommand;
		Command._Name = CommandName;
		Command._Use = Use;
		if(flags.length > 0)
		{
			foreach(Flag; flags)
			{
				Command._Flags[Flag] = true;
			}
		}
		Command._fp = fp;
		CommandList ~= Command;
		return 1;
	};

	string[] ParseText(string Input)
	{
		string[] TokenList;
		string TokenString;

		enum ParseMode
		{
			WhiteSpace=0,
			DoubleQuote=1,
			SingleQuote=2,
			Token=3
		};

		ParseMode Mode;

		foreach(char c; Input)
		{
			switch(Mode)
			{
			case ParseMode.WhiteSpace:
			{
				if(c == '\'')
				{
					Mode = ParseMode.SingleQuote;
				}
				if(c == '\"')
				{
					Mode = ParseMode.DoubleQuote;
				}
				if(c == ' ' || c == '\t')
				{
				}
				else
				{
					TokenString ~=c;
					Mode = ParseMode.Token;
				}
			}
			break;
			case ParseMode.DoubleQuote:
			{
				if(c == '\"')
				{
					TokenList ~= TokenString;
					TokenString = null;
					Mode = ParseMode.WhiteSpace;
				}
				else
				{
					TokenString ~= c;
				}
			}
			break;
			case ParseMode.SingleQuote:
			{
				if(c == '\'')
				{
					TokenList ~= TokenString;
					TokenString = null;
					Mode = ParseMode.WhiteSpace;
				}
				else
				{
					TokenString ~= c;
				}
			}
			break;
			case ParseMode.Token:
			{
				if(c == '\"')
				{
					TokenList ~= TokenString;
					TokenString = null;
					Mode = ParseMode.DoubleQuote;
				}
				if(c == '\'')
				{
					TokenList ~= TokenString;
					TokenString = null;
					Mode = ParseMode.SingleQuote;
				}
				if(c == ' ' || c == '\t')
				{
					TokenList ~= TokenString;
					TokenString = null;
					Mode = ParseMode.WhiteSpace;
				}
				else
				{
					TokenString ~= c;
				}
			}
			break;
			}
		}
		if(TokenString.length > 0)
		{
			TokenList ~= TokenString;
		}
		if(TokenList.length > 0)
		{
			return TokenList;
		}
		else
		{
			return null;
		}
	};

	int ExecuteCommand(cAccount Account, string Input)
	{
		string[] TokenList;
		string Direction;
		TokenList = ParseText(Input);
		cRoom Room;
		if(TokenList !is null)
		{
			Room = GlobalWorld.GetRoom(Account.Location);
			if(Room !is null)
			{
				if(Room.ExitList.length > 0)
				{
					foreach(Exit; Room.ExitList)
					{
						Direction = tolower(TokenList[0]);
						if(CompareString(Exit._Name, Direction)==0)
						{
							Account.Client.Send("{xmoved direction " ~ Exit._Name ~ "{n");
							MoveAccount(Account,Account.Location, Exit);
							cmd_look(Account,["look"]);
							return 1;
						}
					}
				}
			}
			if(CommandList.length > 0)
			{
				foreach(Command; CommandList)
				{
					if(("exact" in Command._Flags) !is null)
					{
						if(Command._Name == TokenList[0])
						{
							return Command._fp(Account,TokenList);
						}
					}
					else
					{
						if(CompareString(Command._Name,TokenList[0])==0)
						{
							return Command._fp(Account,TokenList);
						}
					}
				}
			}
			return 1;
		}
		Account.Client.Send("Command Not Found{n");
		return 1;
	};

	int Startup()
	{
		AddCommand("@shutdown",["exact"],&cmd_admin_shutdown ,"shutdown");
		AddCommand("@flag" , null, &cmd_admin_flag, "flag <target account> (<set> <flag name> <value>, <get> <flag name>, <list>)");
		AddCommand("@create",null ,&cmd_olc_create,"@create <type[zone,room,item,mob]> <name> (<key>) (<zonekey>)");
		AddCommand("@link"	,null ,&cmd_olc_link, "@link <source> <target> <direction> , source and taget can be 'here'");
		AddCommand("@unlink", null , &cmd_olc_unlink, "@unlink <source> <direction>");
		AddCommand("@dig" , null , &cmd_olc_dig, "@dig <direction> <room name> <room key>");
		AddCommand("@name", null, &cmd_olc_name, "@name <target> <new name>");
		AddCommand("@edit"	,null ,&cmd_olc_edit ,"edit <target> <property>");
		AddCommand("@list" , null, &cmd_olc_list,"@list <[zones,rooms]> (<zonekey>)");
		AddCommand("@teleport",null, &cmd_admin_teleport, "@teleport <location>");
		AddCommand("@color", null ,&cmd_olc_color,"@color");
		AddCommand("who"	,null ,&cmd_who ,"who");
		AddCommand("tell"	,null ,&cmd_tell ,"tell <target> \"<message>\"");
		AddCommand("gossip"	,null ,&cmd_gossip ,"gossip \"<message>\"");
		AddCommand("use"	,null ,&cmd_use ,"use <target command>");
		AddCommand("quit"	,["exact"] ,&cmd_quit ,"quit");
		AddCommand("look"	,null ,&cmd_look, "look (<target>)");
		AddCommand("inventory"	,null ,&cmd_inventory, "inventory");
		return 1;
	};
	int Frame()
	{
		return 1;
	};
	int Shutdown()
	{
		return 1;
	};
};


