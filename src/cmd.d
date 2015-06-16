
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.conv;
import std.string;

import accounts;
import network;
import stringutilities;
import world;
import item;
import interpreter;

int cmd_quit(cAccount Account, string[] TokenList)
{
	Account.State = "DEAD";
	Account.Client.Send("{x{nGood Bye{n{x");
	if(Account.Location.Room !is null)
	{
		Account.Location.Room.RemAccount(Account._Name);
	}
	return 0;
}

int cmd_look(cAccount Account, string [] TokenList)
{
	cRoom Room;
	string Output;

	Room = GlobalWorld.GetRoom(Account.Location);
	if(Room !is null)
	{
		Output = "{n{W" ~ Room._Name;
		if(Account.GetFlag("admin"))
		{
			Output ~= " {gk{W[{x" ~Room._Key ~"{W]{C #{W"~ to!string(Room._ID) ~ " {gzk{W[{x" ~ Account.Location._ZoneTag ~ "{W]{C z#{W" ~ to!string(Account.Location._ZoneID) ~ "{x{n{n";
		}
		else
		{
			Output ~= "{x{n{n";
		}
		Output ~= Room.PropertyList.Get("core_description");
		Output ~= "{x{n{n[Exit List]{n {Y";//place holders

		if(Room.ExitList.length > 0)
		{
			foreach(Exit; Room.ExitList)
			{
				Output ~= Exit._Name ~ " ";
			}
		}
		Output ~= "{n{x[Player List]{n";//place holders
		if(Room.AccountList.length > 0)
		{
			foreach(Player; Room.AccountList)
			{
				if(Player.GetFlag("admin"))
				{
					Output ~= "{G";
				}
				else
				{
					Output ~= "{x";
				}
				Output ~= Player._Name ~ "{n";
			}
		}
	}
	else
	{
		Output = "{n{W[{RError room not found{W]{n{x";
	}
	Account.Client.Send(Output);
	return 1;
}



int cmd_who(cAccount Account, string[] TokenList)
{
	string Output;
	cAccount[] CharacterList;
	if(GlobalAccountManager.ActiveAccountList.length > 0)
	{
		Output = "{x{WThere are " ~ to !string(GlobalAccountManager.ActiveAccountList.length) ~ " Online{n{n";
		foreach(Character; GlobalAccountManager.ActiveAccountList)
		{
			if(Character.State == "CONNECTED")
			{
				CharacterList ~= Character;
			}
		}
		if(CharacterList.length > 0)
		{
			foreach(Character; CharacterList)
			{
				{
					Output ~= Character._Name ~ "{n{x";
				}
			}
		}
		Output ~= "{nwho - command{x";
		Account.Client.Send(Output);
	}
	return 1;
}

int cmd_tell(cAccount Account, string[] TokenList)
{
	string Output;
	string Message;
	string Target;

	if(TokenList.length > 2)
	{
		Target = TokenList[1];
		Message = join(TokenList[2..TokenList.length]," ");

		foreach(Character; GlobalAccountManager.ActiveAccountList)
		{
			if(Character.State == "CONNECTED")
			{
				if(ToLower(Character._Name) == ToLower(Target))
				{
					Character.Client.Send("{x{n" ~ Account._Name ~ " sent you \"" ~ Message ~ "{x\"{n");
					Account.Client.Send("{x{nYou Tell " ~ Character._Name ~ " \"" ~ Message ~ "{x\"{n");
					return 1;
				}
			}
		}
	}
	Account.Client.Send("{x{nTarget \'" ~ Target ~ "{x\' Not Found{n");
	return 1;
}

int cmd_gossip(cAccount Account, string[] TokenList)
{
	string Output;
	string Message;

	cAccount[] CharacterList;
	int i;

	if(TokenList.length > 1)
	{
		Message = join(TokenList[1..TokenList.length]," ");

		Output = "{n{xYou Gossiped \"" ~ Message ~ "{x\"{n";
		foreach(Character; GlobalAccountManager.ActiveAccountList)
		{
			if(Character.State == "CONNECTED")
			{
				CharacterList ~= Character;
			}
		}

		if(CharacterList.length > 0)
		{
			foreach(Character; CharacterList)
			{
				if(Character._Name == Account._Name)
				{
					Character.Client.Send(Output);
				}
				else
				{
					Character.Client.Send("{n{x" ~ Account._Name ~ " Gossiped \"" ~ Message ~ "{x\"{n");
				}
			}
		}
	}
	return 1;
}

int cmd_inventory(cAccount Account, string [] TokenList)
{
	string Output = "{x[Inventory]{n";
	if(Account.Inventory.Items.length > 0)
	{
		foreach(Item; Account.Inventory.Items)
		{
			Output ~= Item._Name;
			if(Item.ItemList.Items.length > 0)
			{
				Output ~= " [" ~to!string(Item.ItemList.Items.length) ~ "]{n{x";
			}
			else
			{
				Output ~= "{n{x";
			}
		}
	}
	else
	{
		Output ~= "Inventory Empty...{n{x";
	}
	Account.Client.Send(Output);
	return 1;
}


int cmd_use(cAccount Account, string [] TokenList)
{
	string Output;
	string Target;
	if(GlobalInterpreter.CommandList.length >= 0)
	{
		if(TokenList.length == 1)
		{
			Output = "{x{nCommand Usage{n";
			foreach(Command; GlobalInterpreter.CommandList)
			{
				Output ~= Command._Name ~ "{n";
			}
		}
		if(TokenList.length == 2)
		{
			Target = TokenList[1];
			Output = "{x{nCommand Usage{n";
			foreach(Command; GlobalInterpreter.CommandList)
			{
				if(CompareString(Command._Name, Target)==0)
				{
					Output ~= "{n{g" ~ Command._Name ~ " - {x" ~ Command._Use;
				}
			}
		}
		Account.Client.Send(Output);
	}
	return 1;
}
