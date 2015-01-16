# PreSearch module for ZNC
This is a PreSearch module for the [ZNC IRC Bouncer](http://znc.in/) written in Perl.

Are you already running a PreBot? If not, just take a look at the [ZNC PreBot module](https://github.com/m4luc0/ZNC-PreBot/). This module extends your bnc with the capability of specific Pre searches. Just grab the module, edit the MySQL DB settings and start being a PreSearch Bot.

##How does it work?
The module checks your private messages for "Pre" commands like **!pre, !dupe, !new, !grp, etc**. If it's a command the module will return the results from your PreDB as a private irc message to the sender. The module offers some MySQL configuration variables. It will allow you to use your own db structure and column names.

#### Known commands
**!pre release.name-group** - *Search for specific release*<br />
**!dupe bla bla bla** - *Search for dupes*<br />
**!grp, !group groupname (section)** - *Last 10 group releases (by section)*<br />
**!new section** - *Last 10 section releases*<br />
**!nukes (group/section -g/-s)** - Last 10 nukes (by group/by section)<br />
**!top** - *All-time Top 10 groups*<br />
**!top section** - *Top 5 groups of a section*<br />
**!day, !today, !week, !month, !year** - *Stats for a specific time period*<br />
**!stats** - *Extended PreDB stats*<br />
**!stats group** - *Group stats*<br />
**!db** - *Short PreDB stats*<br />
**!help, !cmds** - *Known commands*

It's pretty simple to use and easy to understand.
I've tried to comment everything that could be important for a better code understanding,
so even perl beginners should be able to use and modify it for custom purposes.

## Prerequisites

* ZNC installed and running. Don't know how to install it? Take a look at the [official guide](http://wiki.znc.in/Installation).
* MySQL server running. In case you're using another DB type you'll have to rewrite some code lines.
* Knowledge about starting Perl modules in ZNC. Don't know how to do that? Take a look at the ZNC [Modperl wiki page](http://wiki.znc.in/Modperl).
* Last but not least, a non empty PreDB. Take a look at the [db_schema](https://github.com/m4luc0/ZNC-PreSearch/blob/master/db_schema.sql) if you're not sure how your PreDB could look like.

## Installation
Make sure that you've configured ZNC with the **--enable-perl** flag. Don't know what I'm talking about? Take a look at the ZNC [Modperl wiki page](http://wiki.znc.in/Modperl). Furthermore I assume that your MySQL server is running with a prepared and non empty db, so you just need to install some Perl modules. The best way to install Perl modules is via [cpanm](https://metacpan.org/pod/App::cpanminus). To install the required packages just type the following commands into your shell:

**1.** Install _cpanm_ (if you're not already using it)
```powershell
curl -L https://cpanmin.us | perl - --sudo App::cpanminus
```

**2.** Install the required Perl modules
```powershell
cpanm POE::Component::IRC
cpanm IRC::Utils
cpanm experimental
cpanm DBI
cpanm DBD::mysql
```

## Usage

**1.** Download the *PreSearch.pm* file to the ZNC modules directory
```powershell
cd ~/.znc/modules
wget https://raw.githubusercontent.com/m4luc0/ZNC-PreSearch/master/PreSearch.pm
```
**2.** Open the file with your favorite text editor and change the MySQL DB settings.

**3.** Start the module via IRC or webpanel. To start via IRC type in the following code into your client:
```
/msg *status loadmod PreSearch
```

## Support
If you need support on any issue about ZNC just say hello at the **#znc** channel on [freenode](https://webchat.freenode.net/). I'll be there too, you can drop me a line if you need specific help for this module.
Check the [changelog](https://github.com/m4luc0/ZNC-PreSearch/blob/master/CHANGELOG.md) for new features or changes.

## Any suggestions or bugs?
Have a bug or a feature request? Or you know how I can improve the code quality?
[Please open a new issue](https://github.com/m4luc0/ZNC-PreSearch/issues).  
__Before opening any issue, please search for existing issues.__
