Neo4J Instance
==============

This bash script was mainly written to manage different instances of neo4j on a development system.  I decided to make it available for
people who find themselves in the same boat.  It doesn't require much, since it is written totally in bash script.  Make sure you have 
wget, or curl installed and you should be all set.

###USAGE
```
  help                           outputs this document
  create [option]                create a new database instance
  	  options:
	     -d <db name>            sets the name of the neo4j instance
	     -t <neo4j type>         sets the neo4j type (community | enterprise)
	     -v <neo4j version>      sets neo4j version (default: 2.1.6)
  rename-db <port> <db name>     renames the db neo4j instance
  start <port>                   starts a neo4j instance
  stop <port>                    stops a neo4j instance
  destroy <port>                 destroys a database instance
  list                           list the different databases,
                                 with their ports and their status
```
