#!/bin/sh
# This is a bash script that outputs a CSV that will show
# the amount of bugs, features, and chores that each user
# owns in each project that the username and password provided
# has access to.
#
# I am not an expert in BASH so please feel free to make any changes
# to my ugly code.

EXPECTED_ARGS=2
METRIC_FILE=metrics.csv

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage is $0 <UserName> <password>"
  exit 0
fi

touch $METRIC_FILE

TOKEN=$(curl -s -u $1:$2 -X GET https://www.pivotaltracker.com/services/v3/tokens/active | xmlstarlet sel -t -m "(/token)" -v "(guid)")

PROJECTXML=$(curl -s -H "X-TrackerToken: $TOKEN" -X GET https://www.pivotaltracker.com/services/v3/projects )
PROJECTS=$(echo "$PROJECTXML" | xmlstarlet sel -t -m "(/projects/project)" -n -v "(id)" -e name -v "(name)" | awk 'BEGIN {FS = "[<]|[>]"} {print $1 " " $3}')

while read -r id name
do
	echo ",$name,," >> $METRIC_FILE
	if [[ $id != "" ]]
	then
	  echo "Developer,Features,Chores,Bugs" >> $METRIC_FILE
	fi
	
	STORIES=$(curl -s -H "X-TrackerToken: $TOKEN" -X GET https://www.pivotaltracker.com/services/v3/projects/$id/stories)
  NAMES=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -v "(owned_by)" -n | tr -s '\n' | sort | uniq)

  while read -r line
  do
	  FEATURES=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -i "(owned_by[.='$line'])" -v "count(story_type[.='feature'])" -n | awk '{ s += $1 } END { print s}' ) 
		BUGS=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -i "(owned_by[.='$line'])" -v "count(story_type[.='bug'])" -n  | awk '{ s += $1 } END { print s}' ) 
		CHORES=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -i "(owned_by[.='$line'])" -v "count(story_type[.='chore'])" -n  | awk '{ s += $1 } END { print s}' ) 
		echo "$line," "$FEATURES," "$BUGS," "$CHORES" >> $METRIC_FILE
	done <<< "$NAMES"	
	echo "" >> $METRIC_FILE
done <<< "$PROJECTS"