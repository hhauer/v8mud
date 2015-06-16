
//          Copyright Harley Hauer 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.file;
import std.stdio;
import std.date;

// GLOBALS
cLogger GlobalLog;

enum LogLevel
{
	CRITICAL,
	ERROR,
	WARNING,
	NOTICE,
	GENERAL
}

class cLogger
{
	this(string fname, LogLevel v = LogLevel.GENERAL)
	{
		if (!exists("logs"))
			mkdirRecurse("logs");

		filename = "logs/" ~ fname ~ ".log";
		raw_log("Log Opened: " ~ toDateString(getUTCtime()), false);
		verbosity = v;
	}
	this()
	{
		this("log");
	}

	~this()
	{
		raw_log("Log Closed: " ~ toDateString(getUTCtime()), false);
	}

	void log(string log_string, LogLevel v = LogLevel.GENERAL)
	{
		if (v >= verbosity)
		{
			raw_log(log_string);
		}
	}

	void loud_log(string log_string, LogLevel v = LogLevel.GENERAL)
	{
		if (v >= verbosity)
		{
			log(log_string, v);
			writeln(log_string);
		}
	}

private:
	string filename;

	LogLevel verbosity;

	void raw_log (string log_string, bool log_time = true)
	{
		try
		{
			if (log_time is true)
				append(filename, "[" ~ toTimeString(getUTCtime()) ~ "] - " ~ log_string ~ "\r\n");
			else
				append(filename, log_string ~ "\r\n");
		}
		catch (FileException xy)
		{
			writefln("A file exception occured writing to the log: " ~ xy.toString());
		}
		catch (Exception xy)
		{
			writefln("An uncaught exception occured writing to the log: " ~ xy.toString());
		}
	}
}
