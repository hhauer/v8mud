
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.conv;
import std.file;
import std.string;
import std.algorithm;
import std.xml;

import item;
import mudobject;
import propertylist;
import accounts;
import stringutilities;

// GLOBALS
cWorld GlobalWorld;

class cWorld : cMudObject

{
	string _ReverseDirection[string];
	string _WorldDir;
	string _WorldFile;

	cZone[] ZoneList;
	this()
	{
		_Type = "world";
		_Name = "World Zone List";
		_ReverseDirection["north"] = "south";
		_ReverseDirection["south"] = "north";
		_ReverseDirection["east"] = "west";
		_ReverseDirection["west"] = "east";
		_ReverseDirection["up"] = "down";
		_ReverseDirection["down"] = "up";
	}
	~this()
	{
	}

	string GetReverseDirection(string Direction)
	{
		string Reverse;
		if((tolower(Direction) in _ReverseDirection) is null)
		{
			return null;
		}
		return _ReverseDirection[Direction];
	}

	int Load(string FileName)
	{
		cZone Zone;
		if(exists(FileName))
		{
			string s = cast(string)std.file.read(FileName);
			check(s);

			auto children = new DocumentParser(s);

			super.Load(children);
			children.onStartTag["ZoneList"]=(ElementParser ep2)
			{
				ep2.onStartTag["Zone"]=(ElementParser ep3)
				{
					Zone = new cZone;
					ep3.onEndTag["Name"]=(in Element e)
					{
						Zone._Name = e.text;
					};
					ep3.onEndTag["File"]=(in Element e)
					{
						Zone._FileName = e.text;
					};
					ep3.parse();

					writeln(Zone._FileName);
					Zone.Load(Zone._FileName);
					ZoneList ~= Zone;
				};
				ep2.parse();
			};
			children.parse();
			return 1;
		}
		return 0;
	};

	int Save (string  FileName)
	{
		auto doc = new Document(new Tag("world"));
		super.Save(doc);

		auto zonelist = new Element("ZoneList");
		if(ZoneList.length > 0)
		{
			foreach(Zone; ZoneList)
			{
				auto zoneElement = new Element("Zone");
				zoneElement ~= new Element("Name", Zone._Name);
				zoneElement ~= new Element("File", Zone._FileName);
				Zone.Save(Zone._FileName);
				zonelist ~= zoneElement;
			}
		}
		doc ~= zonelist;

		std.file.write(FileName, doc.prolog ~ "\r\n" ~ join(doc.pretty(4),"\r\n") ~ "\r\n");
		return 1;
	};
	int ValidateExits()
	{
		writeln("\t\tLinking Exits");
		if(ZoneList.length > 0)
		{
			foreach(Zone; ZoneList)
			{
				writeln("\t\tZone:",Zone._Name);
				if(Zone.RoomList.length > 0)
				{
					foreach(Room; Zone.RoomList)
					{
						writeln("\t\t\tRoom:",Room._Name);
						if(Room.ExitList.length > 0)
						{
							foreach(Exit; Room.ExitList)
							{
								if(Exit.Validate())
								{
									writeln("\t\t\t\t",Exit._Name," Valid");
								}
								else
								{
									writeln("\t\t\t\t",Exit._Name, " Invalid");
								}
							}
						}
					}
				}
			}
		}
		return 1;
	}
	int NewWorld(string Filename)
	{
		cZone Zone;
		cRoom Room;

		Zone = AddZone("default","default");
		Room = Zone.AddRoom("default","default");
		Room.PropertyList.Set("core_description","This is the default description,{ncontact builder or owner to have them revise this description");
		return 1;
	};

	int WorldDirectory(string Directory)
	{
		_WorldDir = Directory;
		if(exists(_WorldDir))
		{
			writeln("\t\tWorld directory exist continuing");
			return 1;
		}
		else
		{
			writeln("\t\tCreating World Directory");
			mkdirRecurse(Directory);
			return 0;
		}
	};

	void SetWorldDir(string Directory)
	{
		_WorldDir = Directory;
	};
	string GetWorldDir()
	{
		return _WorldDir;
	};

	void SetWorldFile(string File)
	{
		_WorldFile = File;
	}
	string GetWorldFile()
	{
		return _WorldFile;
	}

	cRoom GetRoom(cLocation Location)
	{
		cRoom Room;
		if(Location !is null)
		{
			if(Location.Room !is null)
			{
				return Location.Room;
			}
			else
			{
				Room = GetRoom(Location._ZoneID, Location._RoomID);
				if(Room !is null)
				{
					Location.Room = Room;
					return Room;
				}
			}
		}
		return null;
	}

	cLocation GetLocation(string LocationString)
	{
		cLocation Location= new cLocation;
		cZone Zone;
		cRoom Room;
		string ZoneKey;
		string RoomKey;
		LocationString = tolower(LocationString);
		string[] Keys = split(LocationString,"@");

		if(Keys.length == 2)
		{
			ZoneKey = Keys[1];
			RoomKey = Keys[0];

			Zone = GetZoneKey(ZoneKey);
			if(Zone !is null)
			{
				Room = Zone.GetRoomKey(RoomKey);
				if(Room !is null)
				{
					Location._ZoneID = Zone._ID;
					Location._RoomID = Room._ID;
					Location._ZoneTag = ZoneKey;
					Location._RoomTag = RoomKey;
					Location.Room = Room;

					return Location;
				}
			}
		}
		return null;
	}

	cZone AddZone(string ZoneName,string ZoneKey)
	{
		writeln("\t\tAdding Zone ",ZoneName);

		if(ZoneList.length > 0)
		{
			foreach(Zone; ZoneList)
			{
				if(ZoneKey == Zone._Key)
				{
					return null;
				}
				if(ZoneName == Zone._Name)
				{
					return null;
				}
			}
		}

		string [] splitzonename;
		string zonefilename;

		splitzonename = split(ZoneName," ");
		zonefilename = _WorldDir ~ "/" ~ join(splitzonename,"");
		zonefilename ~= ".xml";


		cZone Zone = new cZone();

		Zone._Name = ZoneName;
		Zone._ID = FreeID();
		Zone._FileName = zonefilename;
		Zone._Key = ZoneKey;

		ZoneList ~= Zone;
		return Zone;
	};
	int RemZone(string ZoneName)
	{
		cZone[] TempList;
		int Found=0;
		foreach(Zone; ZoneList)
		{
			if(Zone._Name != ZoneName)
			{
				TempList ~= Zone;
			}
			else
			{
				Found = 1;
			}
		}
		return 1;
	};
	cZone GetZone(string ZoneName)
	{
		if(ZoneList.length > 0)
		{
			foreach(Zone; ZoneList)
			{
				if(Zone._Name == ZoneName)
				{
					return Zone;
				}
			}
		}
		return null;
	};
	cZone GetZone(int ZoneID)
	{
		if(ZoneList.length > 0)
		{
			foreach(Zone; ZoneList)
			{
				if(Zone._ID == ZoneID)
				{
					return Zone;
				}
			}
		}
		return null;
	};

	cZone GetZoneKey(string ZoneKey)
	{
		if(ZoneList.length > 0)
		{
			foreach(Zone; ZoneList)
			{
				if(Zone._Key == ZoneKey)
				{
					return Zone;
				}
			}
		}
		return null;
	}

	cRoom GetRoom(int ZoneID,int RoomID)
	{
		cZone Zone;
		cRoom Room;
		Zone = GetZone(ZoneID);
		if(Zone !is null)
		{
			Room = Zone.GetRoom(RoomID);
			return Room;
		}
		return null;
	};
	cRoom GetRoom(string ZoneName,string RoomName)
	{
		cZone Zone;
		cRoom Room;
		Zone = GetZone(ZoneName);
		if(Zone !is null)
		{
			Room = Zone.GetRoom(RoomName);
			return Room;
		}
		return null;
	};

	int Configure(cPropertyList Config)
	{
		_WorldDir = Config.Get("world_dir");
		if(_WorldDir is null)
		{
			_WorldDir = "world";
			Config.Set("world_dir",_WorldDir);
		}
		_WorldFile = Config.Get("world_file");
		if(_WorldFile is null)
		{
			_WorldFile = "world.xml";
			Config.Set("world_file",_WorldFile);
		}

		return 1;
	};
	int Startup()
	{
		writeln("\t\tChecking Directory");
		if(WorldDirectory(_WorldDir))
		{
			writeln("\t\tLoading World File");
			if(Load(_WorldDir ~ "/" ~_WorldFile)==0)
			{
				NewWorld(_WorldFile);
				Save(_WorldDir ~ "/" ~ _WorldFile);
			}
			else
			{
				writeln("\t\tWorld Loaded");
			}
		}
		else
		{
			NewWorld(_WorldFile);
			Save(_WorldDir ~ "/" ~ _WorldFile);
		}
		ValidateExits();
		return 1;
	};
	int Frame()
	{
		return 1;
	};
	int Shutdown()
	{
		Save(_WorldDir ~ "/" ~ _WorldFile);
		return 1;
	};

	int Send(string Input)
	{
		if(ZoneList.length > 0)
		{
			foreach(Zone; ZoneList)
			{
				Zone.Send(Input);
			}
			return 1;
		}
		return 0;
	}

	int FreeID()
	{
		int IDa;
		int IDb;

		if(ZoneList.length > 0)
		{
			sort!(zonesort)(ZoneList);
			IDb = ZoneList[0]._ID;
			foreach(Zone; ZoneList)
			{
				IDa = Zone._ID;
				if((IDa - IDb) > 1)
				{
					return IDa + 1;
				}
				IDb = IDa;
			}
			return IDa + 1;
		}
		return 0;
	};
}

class cZone : cMudObject
{

	string _FileName;
	int _ID;
	string _Key;
	cRoom[] RoomList;

	this()
	{
		_Type = "zone";
	}
	cRoom AddRoom(string Name,string Key)
	{
		cRoom Room;
		Room = new cRoom;
		Room._Key = Key;
		Room._Name = Name;
		Room._ID = FreeID();
		RoomList ~= Room;
		return Room;
	};
	int RemRoom(int id)
	{
		cRoom [] TempList;
		foreach(Room; RoomList)
		{
			if(Room._ID != id)
			{
				TempList ~= Room;
			}
		}
		RoomList = TempList;
		return 1;
	};
	int RemRoom(string Name)
	{
		cRoom [] TempList;
		foreach(Room; RoomList)
		{
			if(Room._Name != Name)
			{
				TempList ~= Room;
			}
		}
		RoomList = TempList;
		return 1;
	};
	cRoom GetRoom(int id)
	{
		foreach(Room; RoomList)
		{
			if(Room._ID == id)
			{
				return Room;
			}
		}
		return null;
	};
	cRoom GetRoom(string Name)
	{
		foreach(Room; RoomList)
		{
			if(Room._Name == Name)
			{
				return Room;
			}
		}
		return null;
	};
	cRoom GetRoomKey(string RoomKey)
	{
		foreach(Room; RoomList)
		{
			if(RoomKey.length == Room._Key.length)
			{
				if(RoomKey == Room._Key)
				{
					return Room;
				}
			}
		}
		return null;
	};

	int FreeID()
	{
		int IDa;
		int IDb;
		if(RoomList.length > 0)
		{
			sort!(roomsort)(RoomList);
			IDb = RoomList[0]._ID;
			foreach(Room; RoomList)
			{
				IDa = Room._ID;
				if((IDa - IDb) > 1)
				{
					return IDb +1;
				}
				IDb = IDa;
			}
			return IDa + 1;

		}
		return 0;
	};
	int Load(string  FileName)
	{
		int i;
		int NumberOfRooms;
		cRoom Room;
		if(exists(FileName))
		{
			string s = cast(string)std.file.read(FileName);
			check(s);

			auto children = new DocumentParser(s);
			super.Load(children);
			children.onEndTag["ZoneKey"]=(in Element e)
			{
				_Key = e.text;
			};
			children.onEndTag["ID"]=(in Element e)
			{
				if(isNumeric(e.text))
				{
					_ID = to!int(e.text);
				}
			};
			children.onStartTag["RoomList"]=(ElementParser roomlist)
			{
				roomlist.onStartTag["Room"]=(ElementParser E)
				{
					Room = new cRoom;
					Room.Load(E);
					RoomList ~= Room;
				};
				roomlist.parse();
			};
			children.parse();

			return 1;
		}
		return 0;
	};
	int Save(string FileName)
	{
		auto doc = new Document(new Tag("Zone"));
		super.Save(doc);
		doc ~= new Element("ZoneKey", _Key);
		doc ~= new Element("ID",to!string(_ID));

		auto roomlist = new Element("RoomList");
		if(RoomList.length > 0)
		{
			foreach(Room; RoomList)
			{
				roomlist ~= Room.Save();
			}
		}
		doc ~= roomlist;
		std.file.write(FileName,doc.prolog ~ "\r\n" ~ join(doc.pretty(4),"\r\n") ~ "\r\n");

		return 1;
	}
	int Send(string Input)
	{
		if(RoomList.length > 0)
		{
			foreach(Room; RoomList)
			{
				Room.Send(Input);
			}
			return 1;
		}
		return 0;
	}
}

class cRoom : cMudObject
{
	cAccount[string] AccountList;
	cLocation[string] ExitList;
	cItemList ItemList;

	string _Owner;
	string _Creator;
	string _Key;
	int _ID;

	this()
	{
		_Type = "room";
		ItemList = new cItemList;
	}

	int Send(string Input)
	{
		if(AccountList.length > 0 )
		{
			foreach(Account; AccountList)
			{
				if(Account.State == "CONNECTED")
				{
					Account.Client.Send(Input);
				}
			}
			return 1;
		}
		return 0;
	}

	cAccount GetAccount(string Name)
	{
		cAccount Account;
		Name = tolower(Name);
		if((Name in AccountList) !is null)
		{
			return AccountList[Name];
		}
		return null;
	}
	cAccount GetPartial(string Name)
	{
		if(AccountList.length > 0)
		{
			foreach(Account; AccountList)
			{
				if(CompareString(tolower(Account._Name),tolower( Name)))
				{
					return Account;
				}
			}
		}
		return null;
	}
	int AddAccount(cAccount Account)
	{
		if(Account !is null)
		{
			AccountList[tolower(Account._Name)] = Account;
			return 1;
		}
		return 0;
	}
	int RemAccount(string Name)
	{
		if((tolower(Name) in AccountList) !is null)
		{
			AccountList.remove(Name);
		}
		return 1;
	}

	cLocation GetExit(string Direction)
	{
		if((tolower(Direction) in ExitList)!is null)
		{
			return ExitList[tolower(Direction)];
		}
		return null;
	};
	int SetExit(string Direction,cLocation Location)
	{
		cLocation Temp;
		Temp = new cLocation;
		Temp._RoomID = Location._RoomID;
		Temp._RoomTag = Location._RoomTag;
		Temp._ZoneID = Location._ZoneID;
		Temp._ZoneTag = Location._ZoneTag;
		Temp._Name = Direction;
		Temp.Validate();
		ExitList[tolower(Direction)] = Temp;
		return 1;
	};
	int RemExit(string Direction)
	{
		if((tolower(Direction) in ExitList)!is null)
		{
			ExitList.remove(tolower(Direction));
			return 1;
		}
		return 0;
	};

	void Load(ElementParser e)
	{
		cLocation Exit;
		super.Load(e);
		e.onEndTag["Owner"]=(in Element e)
		{
			_Owner = e.text;
		};
		e.onEndTag["Creator"]=(in Element e)
		{
			_Creator = e.text;
		};
		e.onEndTag["Key"]=(in Element e)
		{
			_Key=e.text;
		};
		e.onEndTag["ID"]=(in Element e)
		{
			if(isNumeric(e.text))
			{
				_ID = to!int(e.text);
			}
		};
		e.onStartTag["ExitList"]=(ElementParser ep)
		{
			ep.onStartTag["Exit"]=(ElementParser exit)
			{
				Exit = new cLocation;
				Exit.Load(exit);
				ExitList[Exit._Name] = Exit;
			};
			ep.parse();
		};
		e.onStartTag["ItemList"] = &ItemList.Load;
		e.parse();
	};
	Element Save()
	{
		auto room = new Element("Room");
		super.Save(room);
		room ~= new Element("Owner",_Owner);
		room ~= new Element("Creator",_Creator);
		room ~= new Element("Key",_Key);
		room ~= new Element("ID", to!string(_ID));
		auto exitlist = new Element("ExitList");
		if(ExitList.length> 0)
		{
			foreach(Exit; ExitList)
			{
				auto exit = new Element("Exit");
				exit ~= Exit.Save();
				exitlist ~= exit;
			}
		}
		room ~= exitlist;
		room ~= ItemList.Save();
		return room;
	};
}

class cLocation
{
	this()
	{
		Room = null;
	}
	~this()
	{
	}
	void Load(ElementParser e)
	{
		e.onEndTag["zonekey"]=(in Element e)
		{
			_ZoneTag = e.text;
		};
		e.onEndTag["roomkey"]=(in Element e)
		{
			_RoomTag = e.text;
		};
		e.onEndTag["zoneid"]=(in Element e)
		{
			if(isNumeric(e.text))
			{
				_ZoneID = to!int(e.text);
			}
		};
		e.onEndTag["roomid"]=(in Element e)
		{
			if(isNumeric(e.text))
			{
				_RoomID = to!int(e.text);
			}
		};
		e.onEndTag["name"] = (in Element e)
		{
			_Name = e.text;
		};
	}
	Element Save()
	{
		auto e = new Element("Location");
		e ~= new Element("zonekey",_ZoneTag);
		e ~= new Element("zoneid", to!string(_ZoneID));
		e ~= new Element("roomkey", _RoomTag);
		e ~= new Element("roomid", to!string(_RoomID));
		e ~= new Element("name", _Name);
		return e;

	}
	int Validate()
	{
		cZone Zone;
		cRoom ValidRoom;

		Zone = GlobalWorld.GetZone(_ZoneID);
		if(Zone !is null)
		{
			_ZoneTag = Zone._Key;
			ValidRoom = Zone.GetRoom(_RoomID);
			if(ValidRoom !is null)
			{
				_RoomTag = ValidRoom._Key;
				Room = ValidRoom;
				return 1;
			}
		}
		return 0;
	}

	int _ZoneID;
	string _ZoneTag;
	int _RoomID;
	string _RoomTag;
	string _Name;

	cRoom Room;
}

bool zonesort(cZone a, cZone b)
{
	return a._ID < b._ID;
}

bool roomsort(cRoom a, cRoom b)
{
	return a._ID < b._ID;
}

int Link(cLocation  Source, cLocation Target, string Direction)
{
	if(Source !is null)
	{
		Source.Validate();
		if(Target !is null)
		{
			Target.Validate();
			if(Direction !is null)
			{
				if(Source.Room !is null)
				{
					return Source.Room.SetExit(Direction,Target);
				}
			}
		}
	}
	return 0;
}

int MoveAccount(cAccount Account, cLocation Source, cLocation Target)
{
	if(Account !is null)
	{
		if(Source !is null)
		{
			if(Target !is null)
			{
				if(Source.Room.RemAccount(Account._Name))
				{
					if(Target.Room.AddAccount(Account))
					{
						Account.Location = Target;
						return 1;
					}
				}
			}
		}
	}
	return 0;
}
