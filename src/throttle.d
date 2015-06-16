
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.date;
import core.thread;


class cThrottle
{
	this() {};
	~this() {};

	void Start()
	{
		StartTime = getUTCtime();
	}

	void Stop()
	{
		StopTime = getUTCtime();
	}

	void Sleep()
	{
		d_time Elasped;
		Elasped = StopTime - StartTime;

		int TimeToSleep = msFromTime(Elasped);
		if(TimeToSleep < PulseWait)
		{
			TimeToSleep = (PulseWait - TimeToSleep)  * 1000;
			Thread.sleep(TimeToSleep);
		}
	}

	void PulsesPerSecond(int pulses = 10)
	in
	{
		assert(pulses > 0);
	}
	body
	{
		PulseWait = (1000 / pulses);
	}

private:
	d_time StartTime;
	d_time StopTime;
	int PulseWait = 100; // Default to 10 pulses per second.
};
