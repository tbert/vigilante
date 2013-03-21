--
-- SQL to create a Vigilante defect tracking database
--

CREATE TABLE IF NOT EXISTS Projects (
	ID INTEGER PRIMARY KEY ASC AUTOINCREMENT,

	name		TEXT UNIQUE,
	description	TEXT
);

CREATE TABLE IF NOT EXISTS Scans (
	ID INTEGER PRIMARY KEY ASC AUTOINCREMENT,

	projectID	INTEGER NOT NULL,
	tool		TEXT,
	uuid		TEXT UNIQUE, -- UUID chosen as exportable unique key
	externalID	TEXT,	-- Should map to externally-unique key; e.g., source repository version.

	FOREIGN KEY(projectID) references Projects(ID)
);

CREATE TABLE IF NOT EXISTS DefectClasses (
	ID INTEGER PRIMARY KEY ASC AUTOINCREMENT,

	textID		TEXT UNIQUE,	-- Intended to be a 4-letter shorthand
	class		TEXT UNIQUE,
	description	TEXT
);

CREATE TABLE IF NOT EXISTS Defects (
	ID INTEGER PRIMARY KEY ASC AUTOINCREMENT,

	scanID		INTEGER NOT NULL,
	classID		INTEGER NOT NULL,
	file		TEXT,
	lineno		TEXT,
	line		TEXT,
	raw		TEXT,
	firstSeen	INTEGER,	-- Use SQLite date conversion magic
	lastSeen	INTEGER,	-- Use SQLite date conversion magic
	duplicateOf	INTEGER	DEFAULT NULL,

	FOREIGN KEY(classID)	 references DefectClasses(ID)
	FOREIGN KEY(scanID)	 references Scans(ID)
	FOREIGN KEY(duplicateOf) references Defects(ID)
);

INSERT OR IGNORE INTO DefectClasses (textID, class, description) VALUES
	   (
		"UAF",
		"Use after free",
		"Memory is being referenced after it has been released by the program"
	), (
		"INIT",
		"Uninitialized variable",
		"Variable is being used without proper initialization"
	), (
		"NULL",
		"NULL pointer",
		"Pointer is being dereferenced with a value of NULL"
	), (
		"DEDS",
		"Dead store",
		"Assignment to variable which is not subsequently referenced"
	), (
		"DEDC",
		"Dead code",
		"There is no execution path which reaches the referenced code"
	), (
		"TCTU",
		"TOCTOU",
		"There exists a race between the time data is checked and the time it is used"
	), (
		"UNTR",
		"Untrusted input",
		"Input values are not being sufficiently validated"
	), (
		"BOFL",
		"Buffer overflow",
		"Size of buffer is insufficient to store the size of data being written to it"
	), (
		"IOFL",
		"Integer overflow",
		"Integer is not large enough to store the value being written to it"
	), (
		"LOCK",
		"Locking",
		"Locking regime is insufficient to protect data or avoid deadlock"
	), (
		"RTRN",
		"Returns",
		"Return value of function is not properly handled by caller"
	), (
		"LEAK",
		"Resource leak",
		"Program leaks an allocated resource"
	);
