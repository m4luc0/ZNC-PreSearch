# PreSearch module for ZNC
This is a PreSearch module for the [ZNC IRC Bouncer](http://znc.in/) written in Perl.

Are you already running a PreBot? If not, just take a look at the [ZNC PreBot module](https://github.com/m4luc0/ZNC-PreBot/). This module extends your bnc with the capability of specific Pre searches. Just grab the module, edit the MySQL DB settings and start being a PreSearch Bot.

##How does it work?
The module checks your private messages for "Pre" commands like **!pre, !dupe, !new, !grp, etc**. If it's a command the module will return the results from your PreDB as a private irc message. The module offers some MySQL configuration variables. It will allow you to use your own db structure and column names.

```
< Known commands: >
< !pre release.name-group // Search for specific release >
< !dupe release.name-group OR !dupe bla bla bla // Search for dupes >
< !grp groupname // Last 5 group releases >
< !new section // Last 10 section releases >
< !help // Known commands >
```

It's pretty simple to use and easy to understand.
I've tried to comment everything that could be important for a better code understanding,
so even perl beginners should be able to use and modify it for custom purposes.

## Prerequisites

* ZNC installed and running. Don't know how to install it? Take a look at the [official guide](http://wiki.znc.in/Installation).
* MySQL server running. In case you're using another DB type you'll have to rewrite some code lines.
* Knowledge about starting Perl modules in ZNC. Don't know how to do that? Take a look at the ZNC [Modperl wiki page](http://wiki.znc.in/Modperl).
* Last but not least, a non empty PreDB. Your PreDB structure **could** look like this:

```sql
CREATE TABLE IF NOT EXISTS `releases` (
  `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `pretime` int(11) NOT NULL,
  `release` varchar(200) NOT NULL,
  `section` varchar(20) NOT NULL,
  `files` int(5) NOT NULL DEFAULT '0',
  `size` decimal(10,2) NOT NULL DEFAULT '0.00',
  `status` int(1) NOT NULL DEFAULT '0',
  `reason` varchar(255) NOT NULL DEFAULT '',
  `group` varchar(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `release` (`release`),
  KEY `grp` (`group`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;
```

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

## TO-DO
```
!info group - group stats
!top section - best groups of a section
!top - best groups - all-time
!stats - extended db stats
!db - short db stats
!today, !week, !month, !year - db stats for a certain period
```
## Support
If you need support on any issue about ZNC just say hello at the **#znc** channel on [freenode](https://webchat.freenode.net/). I'll be there too, you can drop me a line if you need specific help for this module.

## Any suggestions or bugs?
Have a bug or a feature request? Or you know how I can improve the code quality?
[Please open a new issue](https://github.com/m4luc0/ZNC-PreSearch/issues).  
__Before opening any issue, please search for existing issues.__
