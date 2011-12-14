#!/bin/sh
# This is a bash script that outputs a CSV that will show
# the amount of bugs, features, and chores that each user
# owns in each project that the username and password provided
# has access to.
#
# I am not an expert in BASH so please feel free to make any changes
# to my ugly code.
# I use XMLStarlet heavily, which is a command line tool for XML manipulation.

TOKEN_ARGS=1
EXPECTED_ARGS=2
INTERMEDIATE=inter
METRIC_FILE=metrics.csv


if [ $# == $TOKEN_ARGS ]
then
  TOKEN=$1
elif [ $# == $EXPECTED_ARGS ]
then
  #Get the token used for the header in later requests.
  TOKEN=$(curl -s -u $1:$2 -X GET https://www.pivotaltracker.com/services/v3/tokens/active | xmlstarlet sel -t -m "(/token)" -v "(guid)")
else
  echo "Usage is $0 <UserName> <password> or $0 <token>"
  exit 0
fi

touch $INTERMEDIATE

PROJECTXML=$(curl -s -H "X-TrackerToken: $TOKEN" -X GET https://www.pivotaltracker.com/services/v3/projects )
#Get the names and id's of al the projects that are accessible to the user.
PROJECTS=$(echo "$PROJECTXML" | xmlstarlet sel -t -m "(/projects/project)" -n -v "(id)" -e name -v "(name)" | awk 'BEGIN {FS = "[<]|[>]"} {print $1 " " $3}')

while read -r id name
do
	echo "$name,,," >> $INTERMEDIATE
	#The first time this loop runs, id and name, are always blank and I can't fix it, 
	# so this check ensures the column labels aren't present when no project is.
	if [[ $id != "" ]]
	then
	  echo "Developer,Features,Chores,Bugs" >> $INTERMEDIATE
	fi
	
	STORIES=$(curl -s -H "X-TrackerToken: $TOKEN" -X GET https://www.pivotaltracker.com/services/v3/projects/$id/stories)
	#Get the owner names and remove all duplicate entries, useful with XMLStarlet to count the number of nodes of each story type.
  NAMES=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -v "(owned_by)" -n | tr -s '\n' | sort | uniq)

  while read -r line
  do
	  FEATURES=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -i "(owned_by[.='$line'])" -v "count(story_type[.='feature'])" -n | awk '{ s += $1 } END { print s}' ) 
		BUGS=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -i "(owned_by[.='$line'])" -v "count(story_type[.='bug'])" -n  | awk '{ s += $1 } END { print s}' ) 
		CHORES=$(echo "$STORIES" | xmlstarlet sel -t -m "(/)" -m "(//story)" -i "(owned_by[.='$line'])" -v "count(story_type[.='chore'])" -n  | awk '{ s += $1 } END { print s}' ) 
		echo "$line," "$FEATURES," "$BUGS," "$CHORES" >> $INTERMEDIATE
	done <<< "$NAMES"	
	echo "" >> $INTERMEDIATE
done <<< "$PROJECTS"

cat $INTERMEDIATE | tr -s '\n' | sed '1d;2d' > $METRIC_FILE
rm $INTERMEDIATE

