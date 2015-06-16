
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.xml;

import propertylist;
import mudobject;

class cItemList
{
	cItem[] Items;
	Element Save()
	{
		auto element = new Element("ItemList");
		if(Items.length > 0)
		{
			foreach(Item; Items)
			{
				element ~= Item.Save();
			}
		}
		return element;
	}
	void Load(ElementParser e)
	{
		cItem Item;

		e.onStartTag["Item"]=(ElementParser ep)
		{
			Item = new cItem;
			Item.Load(ep);
			Items ~= Item;
		};
		e.parse();
	}

	int AddItem(cItem Item)
	{
		Items ~= Item;
		return 1;
	}
	cItem RemItem(string ItemName, int ItemNumber = 0)
	{
		cItem[] TempList;
		cItem RetItem=null;
		if(Items.length > 0)
		{
			foreach(Item; Items)
			{
				if(Item._Name == ItemName)
				{
					RetItem = Item;
				}
				TempList ~= Item;
			}
			Items = TempList;
		}
		return RetItem;
	}
	cItem GetItem(string ItemName,int ItemNumber = 0)
	{
		if(Items.length > 0)
		{
			foreach(Item; Items)
			{
				if(Item._Name == ItemName)
				{
					return Item;
				}
			}
		}
		return null;
	}
}

class cItem : cMudObject
{
	this()
	{
		ItemList = new cItemList;
	}
	Element  Save()
	{
		auto e = new Element("Item");
		super.Save(e);

		e ~= new Element("ItemType"	, _ItemType);
		e ~= new Element("Creator" 	, _Creator);
		e ~= new Element("Owner"	, _Owner);
		e ~= ItemList.Save();

		return e;
	}
	void Load(ElementParser base)
	{
		super.Load(base);
		base.onEndTag["ItemType"]=(in Element e)
		{
			_ItemType = e.text;
		};
		base.onEndTag["Creator"]= (in Element e)
		{
			_Creator = e.text;
		};
		base.onEndTag["Owner"] = (in Element e)
		{
			_Owner = e.text;
		};
		base.onStartTag["ItemList"]=&ItemList.Load;
		base.parse();
	}

	string _Creator;
	string _Owner;
	string _ItemType;
	cItemList ItemList;
}
