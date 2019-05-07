module moxane.utils.log;

import std.file;
import std.path : buildPath;
import std.stdio;
import core.sync.mutex;
import std.datetime.systime;
import std.format;

immutable string logFilePath;

private __gshared File logFile;
private __gshared Mutex mutex;

enum LogType {
	info,
	warning,
	critical,
	error
}

private string logTypeString(const LogType type) {
	final switch(type) {
		case LogType.info: return "Info";
		case LogType.warning: return "Warning";
		case LogType.critical: return "Critical";
		case LogType.error: return "Error";
	}
}

void writeLog(const LogType type, lazy string msg) {
	synchronized(mutex) {
		SysTime time = Clock.currTime;
		writeln(logTypeString(type), " ", time.toString, " ", msg);
		logFile.writeln(logTypeString(type), " ", time.toString, " ", msg);
		logFile.flush;
	}
}

void writeLog(lazy string msg) {
	writeLog(LogType.info, msg);
}

void writeLogDebugInfo(int line = __LINE__, /*string file = __FILE__, */string functionName = __FUNCTION__)
(const LogType type, lazy string msg) {
	synchronized(mutex) {
		SysTime time = Clock.currTime;
		writeln(logTypeString(type), " ", time.toString, ":", /*file, ":", */functionName, ":", line, " ", msg);
		logFile.writeln(logTypeString(type), " ", time.toString, ":", /*file, ":", */functionName, ":", line, " ", msg);
		logFile.flush;
	}
}

void writeLogDebugInfo(int line = __LINE__, /*string file = __FILE__, */string functionName = __FUNCTION__)
(lazy string msg) {
	writeLogDebugInfo!(line, /*file, */functionName)(LogType.info, msg);
}

shared static this() {
	logFilePath = buildPath(getcwd, "log.txt");
	logFile = File(logFilePath, "w");
	mutex = new Mutex();
}