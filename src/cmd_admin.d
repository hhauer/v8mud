
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
import main;


int cmd_admin_teleport(cAccount Account, string [] TokenList)
{
	string Target;
	cLocation TargetTele;

	string Output;

	Output = "{W[{BOutput{W]{n{x";

	if(TokenList.length == 2)
	{
		Target = TokenList[1];
		TargetTele = GlobalWorld.GetLocation(tolower(Target));
		if(TargetTele !is null)
		{
			MoveAccount(Account,Account.Location,TargetTele);
			Output ~= "You've Teleported to " ~ TargetTele.Room._Name ~ "{n{x";
		}
		else
		{
			Output ~= "No Target Teleport{n{x";
		}
	}
	Account.Client.Send(Output);
	return 1;
}

int cmd_admin_flag(cAccount Account, string[] TokenList)
{
	string Output="{n{xFlag:";
	cAccount Target = null;

	if(TokenList.length > 1)
	{
		if(tolower(TokenList[1]) == "self")
		{
			Target = Account;
		}
		else
		{
			foreach(Other; GlobalAccountManager.ActiveAccountList)
			{
				if(Other.State == "CONNECTED")
				{
					if(CompareString(Other._Name,TokenList[1]))
					{
						Target = Other;
					}
				}
			}
		}
		if(Target !is null)
		{
			if(TokenList.length == 4)
			{
				if(tolower(TokenList[2]) == "get")
				{
					if(Target.GetFlag(tolower(TokenList[3])))
					{
						Output ~="{n{xFlag:"~TokenList[3]~"=true{n";
					}
					else
					{
						Output ~=TokenList[3]~"=false{n";
					}
				}
			}
			if(TokenList.length == 5)
			{
				if(tolower(TokenList[2]) == "set")
				{
					if(tolower(TokenList[4])=="true")
					{
						Account.SetFlag(tolower(TokenList[3]),true);
						Output ~= TokenList[3] ~ " set to true{n";
					}
					else if(tolower(TokenList[4]) == "false")
					{
						Account.SetFlag(tolower(TokenList[3]),false);
						Output ~= TokenList[3] ~ " set to false{n";
					}
					else
					{
						Output ~= "invalid flag value{n";
					}
				}
			}
			if(TokenList.length == 3)
			{
				if(tolower(TokenList[2]) == "list")
				{
					Output ~= "{n{W[Account Flags]";
					foreach(key; Target.Flags.keys)
					{
						Output ~= "{n{G"~key~"{w={B";
						if(Target.Flags[key])
						{
							Output ~= "true{x";
						}
						else
						{
							Output ~= "false{x";
						}
					}
				}
			}
		}
		Account.Client.Send(Output);
	}
	return 1;
}


int cmd_admin_shutdown(cAccount Account, string[] TokenList)
{
	GlobalRunning = 0;
	return 0;
};
