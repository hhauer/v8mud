
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

//propertylist.d

import std.stdio;
import std.xml;

class cPropertyList
{

	Element Save()
	{
		auto e = new Element("PropertyList");
		if(_PropertyList.length > 0)
		{
			foreach(key; _PropertyList.byKey())
			{
				auto eProperty = new Element("property");
				eProperty ~= new Element("name", key);
				eProperty ~= new Element("value" , encode(_PropertyList[key]));
				e ~= eProperty;
			}
		}
		return e;
	};
	void Load(ElementParser base)
	{
		writeln("\t\tloading PropertyList");
		base.onStartTag["property"] = (ElementParser e)
		{
			string Name;
			string Value;
			
			e.onEndTag["name"] = (in Element ename)
			{
				Name = ename.text;
				writeln("name" , Name);
			};
			e.onEndTag["value"] = (in Element evalue)
			{
				Value = decode(evalue.text);
				writeln("value" , Value);
			};
			e.parse();

			_PropertyList[Name] = Value;
		};
		base.parse();
	};

	string Get(string name)
	{
		return _PropertyList.get(name,null);
	}

	int IsProperty(string name)
	{
		if(_PropertyList.get(name, null) is null)
		{
			return 0;
		}
		return 1;
	}

	void Remove(string name)
	{
		_PropertyList.remove(name);	
	}
	
	void Set(string name,string value)
	{
		_PropertyList[name] = value;
	}
private:
	string [string] _PropertyList;
}