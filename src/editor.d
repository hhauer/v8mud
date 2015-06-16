
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


import std.stdio;
import std.string;
import std.conv;
import std.array;

import accounts;
import interpreter;
import mudobject;

class cEditor
{
	cMudObject Target;
	string Namespace;
	string Property;
	string Value;
	cInterpreter Interpreter;
	string[] ValueLines;

	this(cMudObject NewTarget)
	{
		Target = NewTarget;
		Interpreter = new cInterpreter;
		Interpreter.AddCommand("disp", null, &editor_disp,"");
		Interpreter.AddCommand("exit", null, &editor_exit,"");
		Interpreter.AddCommand("raw", null, &editor_raw,"");
		Interpreter.AddCommand("nl", null, &editor_newline,"");
		Interpreter.AddCommand("reml", null, &editor_remline,"");
		Interpreter.AddCommand("repl", null, &editor_replaceline,"");
		Interpreter.AddCommand("repw", null, &editor_replaceword,"");
		Interpreter.AddCommand("?", null, &editor_help,"");
		Interpreter.AddCommand("inl", null, &editor_insertline,"");
		Interpreter.AddCommand("help", null, &editor_help,"");
		Interpreter.AddCommand("save", null, &editor_save, "");
		Interpreter.AddCommand("wrap", null, &editor_wrap, "");
	};

	int Edit(cAccount Account, string Input)
	{
		return Interpreter.ExecuteCommand(Account,Input);
	};

	int SetTarget(cMudObject NewTarget)
	{
		Target = NewTarget;
		return 1;
	};
	int SetNamespace(string NewNamespace)
	{
		Namespace = NewNamespace;
		return 1;
	};
	int SetProperty(string NewProperty)
	{
		Property = NewProperty;
		return 1;
	};
	int InitiateEditor(string TargetNamespace,string TargetProperty)
	{
		if(Target !is null)
		{
			Value = Target.PropertyList.Get(TargetProperty);
			if(Value is null)
			{
				Target.PropertyList.Set(TargetProperty,"default text");
				Namespace = TargetNamespace;
				Property = TargetProperty;
				Target._Editing  = 1;
				return 1;
			}
			else
			{
				Namespace = TargetNamespace;
				Property = TargetProperty;
				Target._Editing  = 1;
				ValueLines = split(Value,"{n");
				return 1;
			}
			writeln("Value is null");
		}
		else
		{
			writeln("Target is null");
		}
		return 0;
	}
	int Wrap(int Width)
	{
		string WordValue = join(ValueLines, " ");
		string [] WordList = split(WordValue , " ");

		string [] Lines;
		string [] newline;
		string input;
		int linelength = 0;

		int testlength;

		foreach(Word; WordList)
		{
			testlength = linelength +Word.length + 1;
			writeln("TestLength: ",testlength," Width: ",Width);
			if(Word.length > 0)
			{
				if(testlength > Width)
				{
					writeln("newline");
					input = join(newline, " ");
					Lines ~= input;
					newline.clear();

					newline ~= Word;
					linelength = Word.length + 1;
				}
				else
				{
					newline ~= Word;
					linelength = linelength + (Word.length + 1);
				}
			}
		}

		if(newline.length > 0)
		{
			Lines ~= join(newline," ");
		}

		ValueLines = Lines;
		Value = join(ValueLines, "{n");
		return 1;
	}
	int Save()
	{
		Value = join(ValueLines,"{n");
		Target.PropertyList.Set(Property,Value);
		return 1;
	};
	int ReplaceWord(int Line, int Word, string Text)
	{
		
		return 1;
	}
}

int editor_wrap(cAccount Account, string [] TokenList)
{
	Account.Editor.Wrap(80);
	Account.Client.Send("{n{x[Word Wrap]{n");
	editor_disp(Account,["disp"]);
	return 1;
}

int editor_save(cAccount Account, string [] TokenList)
{
	Account.Editor.Save();
	Account.Client.Send("{W[Saving Token]");
	return 0;
}

int editor_insertline(cAccount Account, string [] TokenList)
{
	int line;
	string [] TempValue;

	string Output = "{W[insert line]";

	int i;

	if(TokenList.length > 3)
	{
		if(isNumeric(TokenList[1]))
		{
			line = to!int(TokenList[1]);
		}
		else
		{
			Output ~= " ~ <line> Token isn't a valid number";
		}

		for(i = 0; i < Account.Editor.ValueLines.length; i++)
		{
			if(i == line)
			{
				TempValue ~= join(TokenList[2..TokenList.length], " ");
			}
			TempValue ~= Account.Editor.ValueLines[i];
		}
		Account.Editor.ValueLines = TempValue;
		Account.Client.Send(Output);
		editor_disp(Account,["disp"]);
	}
	return 1;
}

int editor_replaceword(cAccount Account, string [] TokenList)
{
	int word;
	int line;
	string NewWord;
	string [] WordList;

	string Output = "{W[replace word]";

	if(TokenList.length == 4)
	{
		if(isNumeric(TokenList[1]))
		{
			line = to!int(TokenList[1]);
		}
		else
		{
			Output ~= "{R ~ token <line> is not a number";
		}
		if(isNumeric(TokenList[2]))
		{
			word = to!int(TokenList[2]) - 1;
		}
		else
		{
			Output ~= "{R ~ token <word> is not a number";
		}

		if((line >= 0) && (line < Account.Editor.ValueLines.length))
		{
			WordList = split(Account.Editor.ValueLines[line]," ");
			if((word >= 0) && (word < WordList.length))
			{
				WordList[word] = TokenList[3];
				Account.Editor.ValueLines[line] = join(WordList, " ");
			}
			else
			{
				Output ~= "{R ~ token <word> is out of range";
			}
		}
		else
		{
			Output ~= "{R ~ token <line> is out of range";
		}
	}
	Output ~= "{x{n";
	Account.Client.Send(Output);
	editor_disp(Account,["disp"]);
	return 1;
}

int editor_help(cAccount Account, string [] TokenList)
{
	string Output;
	Output ~= "+-<Editor Help>-------------------------------------------------------------+{n";
	Output ~= "| repw - Replace Word : repw <line> <word> <text>                           |{n";
	Output ~= "| repl - Replace Line : repl <line> <text>                                  |{n";
	Output ~= "| nl -   New Line     : nl <text>                                           |{n";
	Output ~= "| inl -  Instert Line : inl <line> <text>                                   |{n";
	Output ~= "| reml - Remove Line  : reml <line>                                         |{n";
	Output ~= "| raw -  Raw          : raw, raw line                                       |{n";
	Output ~= "| disp - Display      : disp                                                |{n";
	Output ~= "+---------------------------------------------------------------------------+{n";
	Output ~= "| save - Save Value   : save                                                |{n";
	Output ~= "| exit - Exit Editor  : exit                                                |{n";
	Output ~= "+---------------------------------------------------------------------------+{n";
	Output ~= "+---------------------------------------------------------------------------+{n";
	Account.Client.Send(Output);
	return 1;
}

int editor_replaceline(cAccount Account,string [] TokenList)
{
	int iLine;
	string Line;
	string Output;

	if(TokenList.length > 2)
	{
		iLine = to!int(TokenList[1]);
		Line = join(TokenList[2..TokenList.length]," ");
		Account.Editor.ValueLines[iLine] = Line;

		Output = "{W[Replace Line]{n{x";
	}
	else
	{
		Output = "{W[Replace Line]{R ~ not enough perameters{n{x";
	}
	Account.Client.Send(Output);
	editor_disp(Account,["disp"]);
	return 1;
}

int editor_remline(cAccount Account, string[] TokenList)
{
	string Output;
	string[] TempLines;

	int i;
	int linenumber;
	int length = Account.Editor.ValueLines.length;

	if(TokenList.length == 2)
	{
		linenumber = to!int(TokenList[1]);
		if((linenumber >= 0) && (linenumber <= length))
		{
			for(i = 0 ; i < length; i++)
			{
				if(i != linenumber)
				{
					TempLines ~= Account.Editor.ValueLines[i];
				}
			}
			Output = "{W[RemLine]{n{x";
			Account.Editor.ValueLines = TempLines;
		}
		else
		{
			Output = "{W[Remline]{R input out of range";
		}
	}

	Account.Client.Send(Output);
	editor_disp(Account,["disp"]);
	return 1;
}

int editor_newline(cAccount Account, string[] TokenList)
{
	string Line;
	string Output;

	Line = join(TokenList[1..TokenList.length]," ");
	Account.Editor.ValueLines ~= Line;

	Output = "{x[Line Added]{n";
	Account.Client.Send(Output);
	editor_disp(Account,["disp"]);

	return 1;
}

int editor_disp(cAccount Account, string[] TokenList)
{
	string Output;
	string Line;
	string LineNumber;

	int i;

	Account.Editor.Value = join(Account.Editor.ValueLines, "{n");

	Output  = "{n{W[Value Preview]{n{x";
	for(i = 0; i < Account.Editor.ValueLines.length; i++)
	{
		Line = Account.Editor.ValueLines[i];
		Output ~= format("%2d : ",i);
		Output ~= Line;
		Output ~= "{n";
	}
	Output ~= "{W[End Preview]{n{x";

	Account.Client.Send(Output);
	return 1;
}

int editor_raw(cAccount Account, string [] TokenList)
{
	string Output;
	string Value = join(Account.Editor.ValueLines, "{n");
	int i;

	if(TokenList.length == 1)
	{
		Output = "{W[Raw Display]{n{x";

		foreach(c; Value)
		{
			if(c == '{')
			{
				Output ~= "{{";
			}
			else
			{
				Output ~= c;
			}
		}

		Output ~="{n{W[Raw Display]{n{x";
	}
	else if(TokenList.length == 2)
	{
		if(TokenList[1] == "line")
		{
			string Line;
			Output = "{n{W[Raw Display - Line]{n{x";
			for(i = 0; i < Account.Editor.ValueLines.length; i++)
			{
				Line = Account.Editor.ValueLines[i];
				Output ~= format( "%2d : ",i);
				foreach(c; Line)
				{
					if( c == '{')
					{
						Output ~= "{{";
					}
					else
					{
						Output ~= c;
					}
				}
				Output ~= "{n";
			}
			Output ~= "{n{W[Raw Display - Line]{n{x";
		}
	}

	Account.Client.Send(Output);
	return 1;
}

int editor_exit(cAccount Account, string[] TokenList)
{
	Account.Client.Send("{n{W[Exiting Editor]{n{x");
	return 0;
}
