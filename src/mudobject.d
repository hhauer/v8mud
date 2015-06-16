
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


//mudobject.d


import std.stdio;
import std.xml;

import propertylist;

class cMudObject
{
	this()
	{
		PropertyList = new cPropertyList;
		_Editing = 0;
	};
	~this() {};

	void Load(ElementParser baseElement)
	{
		baseElement.onEndTag["Name"] = (in Element e)
		{
			_Name = e.text;
		};
		baseElement.onEndTag["Type"] = (in Element e)
		{
			_Type = e.text;
		};
		baseElement.onStartTag["PropertyList"] = &PropertyList.Load;
	};
	Element Save(Element baseElement)
	{
		baseElement ~= new Element("Name",_Name);
		baseElement ~= new Element("Type",_Type);
		baseElement ~= PropertyList.Save();
		return baseElement;
	};

	int _Editing;
	string _Name;
	string _Type;
	cPropertyList PropertyList;
};

