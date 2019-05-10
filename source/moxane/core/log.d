module moxane.core.log;

import std.file;
import std.path;
import std.stdio;
import core.sync.mutex;
import colorize;
import std.datetime.systime;

class NullLog : Log
{
	this()
	{
		super("nullLog", "Null");
	}

	override void write(Log.Severity s, string msg)
	{return;}
}

class Log
{
	enum Severity
	{
		info,
		debug_,
		warning,
		error,
		panic
	}

	static string severityStrPrnt(const Severity s)
	{
		final switch(s) with(Severity)
		{
			case info: 
				cwrite(color("INFO", fg.light_green));
				return "INFO";
			case debug_: 
				cwrite(color("DEBUG", fg.light_blue));
				return "DEBUG";
			case warning: 
				cwrite(color("WARNING", fg.light_yellow));
				return "WARNING";
			case error: 
				cwrite(color("ERROR", fg.light_red));
				return "ERROR";
			case panic: 
				cwrite(color("INFO", fg.red));
				return "PANIC";
		}
	}

	string name;
	string prettyName;
	protected File file;
	protected Mutex mutex;

	this(string name = "defaultLogger", string prettyName = "Default")
	{
		this.name = name;
		this.prettyName = prettyName;
		file = File(name ~ ".txt", "w");
		mutex = new Mutex;
	}

	~this()
	{
		file.close;
	}

	void write(Severity severity, string message)
	{
		synchronized(mutex)
		{
			cwrite("[ ");
			file.write("[ ");
			file.write(severityStrPrnt(severity));
			cwrite(" ] ");
			file.write("] ");
			cwrite(color(prettyName, fg.light_blue));
			file.write(prettyName);
			cwrite(" @ ");
			file.write(" @ ");
			string time = Clock.currTime.toString();
			cwrite(time);
			file.write(time);
			cwrite(": ");
			cwriteln(message);
			file.write(": ");
			file.writeln(message);
			file.flush;
		}
	}
}