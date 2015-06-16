
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

//stringutilities.d

string ToLower(string input)
{
	string retval;
	int Distance = 'a'-'A';
	foreach(char c; input)
	{
		if(c >= 'A' && c <= 'Z' )
			c += Distance;
		retval ~= c;

	}
	return retval;
};
string ToUpper(string input)
{
	string retval;
	int Distance = 'A'-'a';
	foreach(char c; input)
	{
		if(c >= 'a' && c <= 'z' )
			c += Distance;
		retval ~= c;

	}
	return retval;

};

int CompareString(string a,string b)
{
	if(b.length <= a.length)
	{
		auto tempstring = a[0 .. b.length];
		if(tempstring == b)
		{
			return 0;
		}
		if(tempstring > b)
		{
			return 1;
		}
		if(tempstring < b)
		{
			return -1;
		}
	}
	return -1;

}
