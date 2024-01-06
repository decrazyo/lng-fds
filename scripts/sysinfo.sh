#! sh -s
echo
echo "system name & version:"
echo
#;
uname -a
#;
echo
echo "date & time:"
echo
#;
time
date
uptime
#;
echo
echo "network:"
echo
#;
tcpipstat
#;
echo
echo "memory:"
echo
#;
meminfo
#;
echo
echo "loaded modules:"
echo
#;
lsmod
#;
echo
echo "running processes:"
echo
#;
ps
#;
echo
echo "open files:"
echo
#;
strminfo
#;
echo
echo "environment for this process:"
echo
echo -n "current working directory: "
pwd
env
#;
echo
#;
