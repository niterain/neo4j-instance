neo4j-instance
==============

This is a quick bash script that I created to help maintain my various neo4j instances.

USAGE:
======

$ neo4j-instance create

-- This finds the next available port, and creates a neo4j instance

$ neo4j-instance list

-- This list the status of the available neo4j instances

$ neo4j-instance start <PORT NUMBER>

-- This starts a neo4j instance

$ neo4j-instance stop <PORT NUMBER>

-- This stops a neo4j instance

$ neo4j-instance restart <PORT NUMBER>

-- This restarts a neo4j instance

$ neo4j-isntance destroy <PORT NUMBER>

-- This removed the instance from your system
