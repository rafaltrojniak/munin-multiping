# About
This is simple munin plugin that pings multiple hosts in parallel.
To use it :

* 	copy to your server
*		make symbolic link to it in /etc/munin/plugins directory :

>	cd /etc/munin/plugins ; sudo ln /home/pluginDir/multiping -s multiping

*		configure it in /etc/munin/plugin-conf.d/munin-node, by adding for example:

> [multiping]
> env.hosts localhost otherHost
> env.ping\_args -A -c 9

## Configuration

Configuration based on oryginal multiping configuration - nothing new

*		hosts - list of hosts
*		ping\_args - extra arguments added to pign command (defaults to -c 5 )
