
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


import std.stdio;
import std.string;
import std.conv;

import network;
import interpreter;
import accounts;
import editor;
import world;
import mudobject;
import stringutilities;
import item;


int cmd_olc_color(cAccount Account, string [] TokenList)
{
	string Output;

	Output = "{n{x[Color Codes]{n";
	Output ~= "{r{{r - Red            {R{{R - Bold Red{n";
	Output ~= "{g{{g - Green          {G{{G - Bold Green{n";
	Output ~= "{y{{y - Yellow         {Y{{Y - Bold Yellow{n";
	Output ~= "{b{{b - Blue           {B{{B - Bold Blue{n";
	Output ~= "{m{{m - Magenta        {M{{M - Bold Magenta{n";
	Output ~= "{c{{c - Cyan           {C{{C - Bold Cyan{n";
	Output ~= "{w{{w - White          {W{{W - Bold White{n";
	Output ~= "{x{{n / {{N - New Line {{x / {{X - Default Color{n";

	Account.Client.Send(Output);
	return 1;
}

int cmd_olc_link(cAccount Account, string[] TokenList)
{
	string Output;
	cLocation Source;
	cLocation Target;
	string SourceKey;
	string TargetKey;
	string Direction;

	cRoom SourceRoom;

	Output = "{n{W[{BLink{W]{n";

	if(TokenList.length == 4)
	{
		SourceKey = tolower(TokenList[1]);
		TargetKey = tolower(TokenList[2]);
		Direction = tolower(TokenList[3]);
		if(SourceKey == "here")
		{
			Source = Account.Location;
		}
		else
		{
			Source = GlobalWorld.GetLocation(SourceKey);
		}
		if(TargetKey == "here")
		{
			Target = Account.Location;
		}
		else
		{
			Target = GlobalWorld.GetLocation(TargetKey);
		}
		if(Source !is null)
		{
			Source.Validate();
			if(Target !is null)
			{
				Target.Validate();
				Output ~= "Linking '" ~ SourceKey ~"' to '" ~TargetKey ~" through direction " ~ Direction ~ "{n{x";
				SourceRoom = GlobalWorld.GetRoom(Source);
				SourceRoom.SetExit(Direction,Target);
			}
			else
			{
				Output ~= "{RTarget Not Found{n{x";
			}
		}
		else
		{
			Output ~= "{RSource Not Found{n{x";
		}
	}
	Account.Client.Send(Output);

	return 1;
}

int cmd_olc_unlink(cAccount Account, string[] TokenList)
{
	string Output;
	string Source;
	string Direction;

	cRoom SourceRoom;

	Output = "{W[{BUnlink{W]{n{x";

	if(TokenList.length == 3)
	{
		Source = TokenList[1];
		if(tolower(Source) == "here")
		{
			SourceRoom = Account.Location.Room;
		}
		else
		{
			SourceRoom = GlobalWorld.GetRoom(GlobalWorld.GetLocation(Source));
		}

		Direction = TokenList[2];

		if(SourceRoom !is null)
		{
			if(SourceRoom.RemExit(Direction))
			{
				Output ~= "Removed direction " ~ Direction ~ " from " ~ Source ~ "{n{x";
			}
			else
			{
				Output ~= "Exit not found in " ~ Direction ~ " at " ~ Source ~ "{n{x";
			}
		}
		else
		{
			Output ~= "Source " ~ Source ~ " Not found{n{x";
		}
	}

	Account.Client.Send(Output);

	return 1;
}

int cmd_olc_dig(cAccount Account, string[] TokenList)
{
	//@dig <direction> <room name> <room key>
	string Direction;
	string RoomName;
	string RoomKey;
	string ZoneKey;
	string ReverseDirection;

	string Output;

	cRoom Room;
	cZone Zone;

	cLocation Source;
	cLocation Target;

	Output = "{W[{BDIG{W]{x{n";
	if(TokenList.length >= 4)
	{
		Direction = tolower(TokenList[1]);
		RoomName = join(TokenList[2 .. TokenList.length -1]," ");
		RoomKey = tolower(TokenList[TokenList.length -1]);
		ZoneKey = Account.Location._ZoneTag;
		if(ZoneKey is null)
		{
			Zone = GlobalWorld.GetZone(Account.Location._ZoneID);
			if(Zone !is null)
			{
				ZoneKey = Zone._Key;
			}
		}
		else
		{
			Zone = GlobalWorld.GetZoneKey(ZoneKey);
		}
		if(Zone !is null)
		{
			Room = Zone.AddRoom(RoomName, RoomKey);
			if(Room !is null)
			{
				Room.PropertyList.Set("core_description","This is the default description,{nContact builder or owner to have them revise this description");
				ReverseDirection = GlobalWorld.GetReverseDirection(Direction);
				if(ReverseDirection !is null)
				{
					Target = GlobalWorld.GetLocation(RoomKey~"@"~ZoneKey);
					if(!Target.Validate())
					{
						Output ~= "target didn't validate";
					}
					Source = GlobalWorld.GetLocation(Account.Location._RoomTag ~ "@" ~ Account.Location._ZoneTag);
					if(Source.Validate())
					{
						Output ~= "source didn't validate";
					}
					if(Target !is null)
					{
						Link(Source,Target,Direction);
						Link(Target,Source,ReverseDirection);
						Output ~= "Exits Linked along " ~ Direction ~ "<->" ~ ReverseDirection ~ "{x{n";
						Output ~= "Room Created with key '{C" ~ RoomKey ~ "@" ~ ZoneKey ~ "{x'{n";
					}
				}
				else
				{
					Output ~= "Reversed Direction of '" ~ Direction ~"' Not found Linking Failed{x{n";
					Output ~= "Room Created with key '{C" ~ RoomKey ~ "@" ~ ZoneKey ~ "{x'{n";
				}
			}
			else
			{
				Output ~= "{RRoom Failed to be created {x{n";
			}
		}
		else
		{
			Output ~= "{RZone Failed to be Found {x{n";
		}
	}
	Account.Client.Send(Output);
	return 1;
}

int cmd_olc_create(cAccount Account, string[] TokenList)
{
	//@create <type[zone, room, item, mob, npc ... ect]> <name> (<key> || <Item Type[item, descriptor,  >)(<zonekey> || <Item Location>)
	string Type;
	string Name;
	string Key;
	string ZoneKey;
	string Location;
	string ItemType;
	string Output;

	cZone Zone;
	cRoom Room;
	cItem Item;

	Output ="{n{W[{BCreate Object{W]{X{n";

	if(TokenList.length > 3)
	{
		Type = tolower(TokenList[1]);
		if(Type == "item")
		{
			Name = join(TokenList[2 .. (TokenList.length - 2)]," ");
			ItemType = TokenList[TokenList.length - 2];
			Location = TokenList[TokenList.length - 1];

			Item = new cItem;
			Item._Name = Name;
			Item._Owner = Name;
			Item._Creator = Name;
			Item._ItemType =  tolower(ItemType);
			Item.PropertyList.Set("core_description","this is the default description,contact the owner or creator to have them change this");
			Account.Inventory.AddItem(Item);
			Output ~= "Item Creation Compleated{n{x";

		}
		else if(Type == "zone")
		{
			Name = join(TokenList[2 .. (TokenList.length - 1)]," ");
			Key = TokenList[TokenList.length-1];
			Zone = GlobalWorld.AddZone(Name, Key);
			Output ~= "Zone Created With Name " ~ Name ~ " Key: " ~ Key ~ " ID:"~to!string(Zone._ID);
		}
		else if(Type == "room")
		{
			if(TokenList.length >= 5)
			{
				Name = join(TokenList[2 .. (TokenList.length - 2)]," ");
				Key = TokenList[TokenList.length-2];
				ZoneKey = TokenList[TokenList.length-1];
				Zone = GlobalWorld.GetZoneKey(ZoneKey);
				if(Zone !is null)
				{
					Room = Zone.AddRoom(Name, Key);
					if(Room !is null)
					{
						Room._Owner = Account._Name;
						Room._Creator = Account._Name;
						Room.PropertyList.Set("core_description","This is the default description,{nContact the owner or creator to have them change this");
						Output ~= "Room Created in zone " ~ Zone._Name ~ " with name " ~ Room._Name ~ " with Key: " ~Key ~ " ID: " ~ to!string(Room._ID);
					}
				}
			}
		}
	}
	Output ~= "{x{n";
	Account.Client.Send(Output);
	return 1;
}

int cmd_olc_list(cAccount Account, string[] TokenList)
{
	string Output = "{W[{BList{W]{n{x";
	string ListType;
	cZone TargetZone;

	if(TokenList.length > 1)
	{
		if(TokenList.length == 2)
		{
			if(CompareString("zones",tolower(TokenList[1]))==0)
			{
				Output ~= "{W[{BZone List{W]{x{n";
				if(GlobalWorld.ZoneList.length > 0)
				{
					foreach(Zone; GlobalWorld.ZoneList)
					{
						Output ~= Zone._Name ~ " {Ck{W[{x" ~ Zone._Key ~ "{W]{x{n";
					}
				}
				Output ~= "{W[{BEnd List{W]{x{n";
			}
		}
		else if(TokenList.length == 3)
		{
			if(CompareString("rooms",tolower(TokenList[1]))==0)
			{
				TargetZone = GlobalWorld.GetZoneKey(tolower(TokenList[2]));
				if(TargetZone !is null)
				{
					if(TargetZone.RoomList.length > 0)
					{
						Output ~= "{W[{BRoom List{W]{x{n";
						foreach(Room; TargetZone.RoomList)
						{
							Output ~= Room._Name ~ " {Ck{W[{x" ~ Room._Key ~ "{W]{x{n";
						}
						Output ~= "{W[{BEnd List{W]{x{n";
					}
				}
			}
		}
	}
	Account.Client.Send(Output);
	return 1;
}

int cmd_olc_name(cAccount Account, string[] TokenList)
{
	//@name <target> <new name>
	string Name=null;
	string Output;
	cMudObject Target;

	if(Account.GetFlag("admin"))
	{
		if(TokenList.length > 2)
		{
			Name = join(TokenList[2 .. TokenList.length], " ");
		}
		if(tolower(TokenList[1]) == "here")
		{
			Target = GlobalWorld.GetRoom(Account.Location);
			Target._Name = Name;
			Output ="{x{nName Changed{n";
		}
	}
	else
	{
		Output = "{R{nName Not Changed{nnot admin{x";
	}
	return 1;
}

int cmd_olc_edit(cAccount Account, string[] TokenList)
{
	string Namespace;
	string Property;
	cMudObject Target;

	int EditObject = 0;
	if(Account.GetFlag("admin") || Account.GetFlag("builder"))
	{
		if(TokenList.length == 3)
		{
			if(tolower(TokenList[1]) == "self")
			{
				Target = Account;
			}
			if(tolower(TokenList[1]) == "here")
			{
				Target = GlobalWorld.GetRoom(Account.Location);
			}
			Property  = TokenList[2];
			if(Target !is null)
			{
				if(Account.GetFlag("admin"))
				{
					writeln("\t\tAdmin creating new Property");
					//admins can create new properties
					EditObject = 1;
				}
				else
				{
					if(Target.PropertyList.IsProperty(Property))
					{
						EditObject = 1;
					}
				}
				if(EditObject==1)
				{
					Account.Editor = new cEditor(Target);
					if(Account.Editor.InitiateEditor(Namespace,Property)==1)
					{
						Account.State = "EDITING";
						Account.Client.Send("{W[{GStarting Editor{W]{x");
						editor_disp(Account,null);
						Account.Client.Send("{GEditor{x:>");
					}
					else
					{
						Account.Client.Send("{nTarget '"~ TokenList[1] ~ "' doesn't have namespace '" ~ TokenList[2] ~ "' or property '" ~ TokenList[3] ~ "'{n");
						return 1;
					}
				}
				else
				{
					Account.Client.Send("You don't have permission to create a new property");
					return 1;
				}
			}
		}
		return 0;
	}
	else
	{
		Account.Client.Send("{xNot an admin or builder{n");
	}
	return 1;
}
