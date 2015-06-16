
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.conv;
import std.xml;
import std.file;
import std.string;

import network;
import accounts;
import stringutilities;
import throttle;
import interpreter;
import propertylist;
import logger;
import world;

// GLOBALS
int GlobalRunning;

int main(string[] args)
{
	GlobalLog = new cLogger("v8mud");
	writeln("v8mud - the D mud engine");
	GlobalLog.loud_log("Configuration");

	GlobalLog.loud_log("Startup");
	if(Startup(args) > 0)
	{
		writeln("Frame");
		Frame();
	}
	GlobalLog.loud_log("Shutdown");
	Shutdown();

	return 1;
}

cPropertyList Configure(string[] args)
{
	string ConfigFile;
	cPropertyList Config;

	if(args.length > 0)
	{
		foreach(arg; args)
		{
			writeln("\t\t" ~ arg);
			if(CompareString(arg,"--config=")==0)
			{
				ConfigFile = arg[9 .. arg.length];
			}
		}

		writeln("\t\tdone checking arguments");

		Config = new cPropertyList;

		if(ConfigFile.length == 0)
		{
			ConfigFile = "config.xml";
			writeln("\tConfig File Not Defined - Using 'config.xml'");
		}

		if(exists(ConfigFile))
		{
			string s = cast(string)std.file.read(ConfigFile);
			check(s);

			auto doc = new DocumentParser(s);
			doc.onStartTag["PropertyList"]=&Config.Load;
			doc.parse();
		}
		else
		{
			writeln("\tConfig File Not found Creating new one");
		}

		GlobalServer.Configure(Config);
		GlobalAccountManager.Configure(Config);
		GlobalWorld.Configure(Config);

		auto xml = new Document(new Tag("Config"));
		xml ~= Config.Save();
		std.file.write(ConfigFile,xml.prolog ~ "\r\n" ~ join(xml.pretty(4),"\r\n") ~ "\r\n");
		return Config;
	}
	return null;
}

int Startup(string[] args)
{
	writeln("\tConfiguring System");

	GlobalServer = new cServer();
	GlobalAccountManager = new cAccountManager();
	GlobalInterpreter = new cInterpreter();
	GlobalWorld = new cWorld();

	Configure(args);

	writeln("\tServer.Startup");
	if(GlobalServer.Startup()==0)
	{
		writeln("\tServer.Startup - Failed");
		return 0;
	}
	writeln("\tAccountManager.Startup");
	if(GlobalAccountManager.Startup()==0)
	{
		writeln("\tAccountManager.Startup - Failed");
		return 0;
	}
	writeln("\tInterpreter.Startup");
	if(GlobalInterpreter.Startup()==0)
	{
		writeln("\tInterpreter.Startup - Failed");
		return 0;
	}
	writeln("\tWorld.Startup");
	if(GlobalWorld.Startup()==0)
	{
		writeln("\tWorld.startup - Failed");
		return 0;
	}
	return 1;
}

int Frame()
{
	cThrottle Throttle = new cThrottle();
	GlobalRunning = 1;
	while(GlobalRunning)
	{
		Throttle.Start();

		GlobalServer.Frame();
		GlobalAccountManager.Frame();
		GlobalInterpreter.Frame();
		GlobalWorld.Frame();

		GlobalServer.SendClientBuffer();

		Throttle.Stop();
		Throttle.Sleep();
	}
	return 1;
}

int Shutdown()
{
	writeln("\tWorld.Shutdown");
	GlobalWorld.Shutdown();

	writeln("\tInterpreter.shutdown");
	GlobalInterpreter.Shutdown();

	writeln("\tAccountManager.shutdown");
	GlobalAccountManager.Shutdown();

	writeln("\tServer.Shutdown");
	GlobalServer.Shutdown();

	return 1;
}
