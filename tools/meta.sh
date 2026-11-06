#!/bin/sh
# Creates -meta.xml files for every Apex class/trigger that lacks one.
cd "$(dirname "$0")/../force-app/main/default"
for f in classes/*.cls; do [ -f "$f-meta.xml" ] || printf '<?xml version="1.0" encoding="UTF-8"?>\n<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">\n    <apiVersion>64.0</apiVersion>\n    <status>Active</status>\n</ApexClass>\n' > "$f-meta.xml"; done
for f in triggers/*.trigger; do [ -f "$f-meta.xml" ] || printf '<?xml version="1.0" encoding="UTF-8"?>\n<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">\n    <apiVersion>64.0</apiVersion>\n    <status>Active</status>\n</ApexTrigger>\n' > "$f-meta.xml"; done
