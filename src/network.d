
//          Copyright Tristan Daniel 2010.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


//network.d
import std.socket;
import std.stdio;
import std.array;
import std.conv;

import accounts;
import propertylist;
import stringutilities;

// GLOBALS
cServer GlobalServer;

class cClient
{
public:
	this() {};
	~this() {};

	string Buffer;
	string[] LineBuffer;

	int Lines()
	{
		return LineBuffer.length;
	}
	int ProcessProtocol()
	{
		int i;
		int bufferlength;
		int lastReturn=0;
		string Line;

		bufferlength = Buffer.length;
		for(i = 0; i < bufferlength; i++)
		{
			switch(Buffer[i])
			{
			case 255:        //IAC
			{
				writeln("\tTelnet control character received 'IAC' Advancing buffer");
				i++;
				switch(Buffer[i])
				{
				case 254:        //DONT
				{
					writeln("\t\tTelnet control character received 'DONT'");
				}
				break;
				case 253:        //do
				{
					writeln("\t\tTelnet control character received 'DO'");
				}
				break;
				case 252:        //WONT
				{
					writeln("\t\tTelnet control character received 'WONT'");
				}
				break;
				case 251:        //WILL
				{
					writeln("\t\tTelnet control Character received 'WILL'");
				}
				break;
				default:
				{
					writeln("\t\tunknown option %i",Buffer[i]);
				}
				break;
				};
				i++;
				writeln("\t\t\toption %i",Buffer[i]);
			}
			break;
			case '\n':
			{
				LineBuffer ~=Line;
				Line = null;
			}
			break;
			case '\r':
			{
			}
			break;
			case '\b':
			{
				if(Line.length > 0)
				{
					Line = Line[0..(Line.length -1)];
				}
			}
			break;
			default:
			{
				Line ~= Buffer[i];
			}
			break;
			}
		}
		Buffer = Line;
		return LineBuffer.length;
	}
	int Send(string Input)
	{
		OutBuffer ~= Input;
		return 0;
	};
	int SendBuffer()
	{
		string Output;
		int i;
		if(OutBuffer.length > 0)
		{
			for(i = 0; i <  OutBuffer.length; i++)
			{
				if(OutBuffer[i] == '{')
				{
					i++;
					switch(OutBuffer[i])
					{
					case '{':
					{
						Output ~= "{";
					}
					break;
					case 'X':
					case 'x':        //default
					{
						Output ~= "\033[0;37m";
					}
					break;
					case 'N':
					case 'n':        //newline
					{
						Output ~= "\n\r";
					}
					break;
					case '*':        //not displayed
					{
						Output ~= "\033[8m";
					}
					break;
					case 'r':
					{
						Output ~= "\033[0;31m";
					}
					break;
					case 'R':
					{
						Output ~= "\033[1;31m";
					}
					break;
					case 'g':
					{
						Output ~= "\033[0;32m";
					}
					break;
					case 'G':
					{
						Output ~= "\033[1;32m";
					}
					break;
					case 'y':
					{
						Output ~= "\033[0;33m";
					}
					break;
					case 'Y':
					{
						Output ~= "\033[1;33m";
					}
					break;
					case 'b':
					{
						Output ~= "\033[0;34m";
					}
					break;
					case 'B':
					{
						Output ~= "\033[1;34m";
					}
					break;
					case 'm':
					{
						Output ~= "\033[0;35m";
					}
					break;
					case 'M':
					{
						Output ~= "\033[1;35m";
					}
					break;
					case 'c':
					{
						Output ~= "\033[0;36m";
					}
					break;
					case 'C':
					{
						Output ~= "\033[1;36m";
					}
					break;
					case 'w':
					{
						Output ~= "\033[0;37m";
					}
					break;
					case 'W':
					{
						Output ~= "\033[1;37m";
					}
					break;
					case 'p':
					{
						Output ~= "\033[40;30m";
					}
					break;
					default:
					{
						Output ~= OutBuffer[i];
					}
					break;
					}
				}
				else
				{
					Output ~= OutBuffer[i];
				}
			}
		}
		OutBuffer.clear();
		return S.send(Output);
	}
	string GetLine()
	{
		string Input;
		if(Lines())
		{
			Input = LineBuffer.front();
			LineBuffer.popFront;
			return Input;
		}
		return null;
	}

	string OutBuffer;
	string State;
	Socket S;
};

class cServer
{
public:
	this()
	{
		ConfigList = new cPropertyList;
	};

	~this() {};


	int Configure(cPropertyList Config)
	{
		string Port;
		string MaxConnections;
		if(Config !is null)
		{
			Port = Config.Get("network_port");
			if(Port.length > 0)
			{
				_Port = to !int(Port);
			}
			else
			{
				Config.Set("network_port","4000");
				_Port = 4000;
			}

			MaxConnections = Config.Get("network_maxconnection");
			if(MaxConnections.length > 0)
			{
				_MaxConn = to !int(MaxConnections);
			}
			else
			{
				Config.Set("network_maxconnection","60");
				_MaxConn = 60;
			}
		}
		ConfigList = Config;
		return 0;
	}
	int Startup()
	{
		S= new TcpSocket();
		assert(S.isAlive);
		S.blocking = false;
		S.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR,1);
		writeln("\t\tPort - ",_Port); 
		S.bind(new InternetAddress(to !ushort(_Port)));
		S.listen(5);
		return 1;
	};

	int Frame()
	{
		int recvLength;
		string Input;
		cAccount Account;
		cClient[] TempList;
		SocketSet ReadSet = new SocketSet;
		ReadSet.add(S);
		char [512] Buffer;

		Socket.select(ReadSet,null,null,0);
		if(ReadSet.isSet(S))
		{
			auto TempClient = new cClient;
			TempClient.S = S.accept();
			if(ClientList.length < _MaxConn)
			{
				TempClient.State = "LOGON";
				writeln("\tClient ", TempClient.S.remoteAddress().toString(), " - Connected");
			}
			else
			{
				TempClient.Send("{n{WThe Mud is Currently Full, Please Try Again Later{n{x");
				TempClient.State = "DEAD";
			}
			ClientList ~=TempClient;
		}

		ReadSet.reset();

		if(ClientList.length > 0)
		{
			foreach(Client; ClientList)
			{
				ReadSet.add(Client.S);
			};

			Socket.select(ReadSet,null,null,0);

			foreach(Client; ClientList)
			{
				if(ReadSet.isSet(Client.S))
				{
					recvLength = Client.S.receive(Buffer);
					if(Socket.ERROR == recvLength)
					{
						writeln("\tClient ", Client.S.remoteAddress().toString(), " - SocketError");
					}
					else if(recvLength == 0)
					{
						writeln("\tClient ", Client.S.remoteAddress().toString(), " - Disconnected");
						if(Client.State == "CONNECTED")
						{
							Client.State = "DEAD PASS";
						}
						else
						{
							Client.State = "DEAD";
						}
					}
					else
					{
						Client.Buffer ~= Buffer[0 .. recvLength];
					}

					Client.ProcessProtocol();
				}
				switch(Client.State)
				{
				case "LOGON":
				{
					Client.Send("{GW{gelcome To {RV{W8{BMud {gEngine:{W The Clean Running Engine powered by {CD{n");
					Client.Send("{xEnter Your Account Name{W:{w> ");
					Client.State="LOGON_PROMPT";

				}
				break;
				case "LOGON_PROMPT":
				{
					if(Client.Lines() > 0)
					{
						Input = Client.GetLine();
						Account = GlobalAccountManager.GetAccount(Input);

						if(Account is null)
						{
							Account = new cAccount();
							Account.State = "ACCOUNT NEW";
							Account._Name = ToLower(Input);
						}
						else
						{
							Account.State = "ACCOUNT PASSWORD";
						}
						Account.Client = Client;
						GlobalAccountManager.ActiveAccountList ~= Account;

						Client.State = "CONNECTED";
					}
				}
				break;
				case "CONNECTED":
				{

				} break;
				case "DEAD":
				{

				} break;
				default:
				{
				} break;
				}

				if(Client.State == "DEAD")
				{
					Client.S.shutdown(SocketShutdown.BOTH);
				}
				else
				{
					TempList ~= Client;
				}
			}
			ClientList = TempList;
		}
		return 1;
	};

	int Shutdown()
	{
		S.shutdown(SocketShutdown.BOTH);
		S.close();

		foreach(client; ClientList)
		{
			client.S.shutdown(SocketShutdown.BOTH);
			client.S.close();
		};

		return 1;

	};

	int SendClientBuffer()
	{
		foreach(Client; ClientList)
		{
			if(Client.OutBuffer.length > 0)
			{
				Client.SendBuffer();
			}
		}
		return 1;
	}

	int _Port;
	int _MaxConn;
	Socket S;
	cClient[] ClientList;

	cPropertyList ConfigList;
};
