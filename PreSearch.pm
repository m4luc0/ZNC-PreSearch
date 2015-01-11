##
# PreSearch module for ZNC IRC Bouncer
# Author: m4luc0
# Version: 1.0
##

package PreSearch;
use base 'ZNC::Module';

use POE::Component::IRC::Common; # needed for stripping message colors and formatting
use DBI;                         # needed for DB connection
use experimental 'smartmatch';   # smartmatch (Regex) support for newer perl versions
use IRC::Utils qw(NORMAL BOLD UNDERLINE REVERSE ITALIC FIXED WHITE BLACK BLUE GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN TEAL LIGHT_CYAN LIGHT_BLUE PINK GREY LIGHT_GREY); # Support for IRC colors and formatting

# (My)SQL settings
my $DB_NAME     = 'dbname';       # DB name
my $DB_TABLE    = 'tablename';    # TABLE name
my $DB_HOST     = 'localhost';   # DB host
my $DB_USER     = 'dbuser';  # DB user
my $DB_PASSWD   = 'userpw'; # DB user passwd

# DB Columns
my $COL_PRETIME = 'pretime';     # pre timestamp
my $COL_RELEASE = 'release';     # release name
my $COL_SECTION = 'section';     # section name
my $COL_FILES   = 'files';       # number of files
my $COL_SIZE    = 'size';        # release size
my $COL_STATUS  = 'status';      # 0:pre; 1:nuked; 2:unnuked; 3:delpred; 4:undelpred;
my $COL_REASON  = 'reason';      # reason for nuke/unnuke/delpre/undelpre
my $COL_GROUP   = 'group';       # groupname

sub description {
    "PreSearch Perl module for ZNC"
}

sub OnPrivMsg {
    my $self = shift;
    my ($user, $message) = @_;
    my $nick = $user->GetNick;

    # Strip colors and formatting
    if (POE::Component::IRC::Common::has_color($message)) {
        $message = POE::Component::IRC::Common::strip_color($message);
    }
    if (POE::Component::IRC::Common::has_formatting($message)) {
        $message = POE::Component::IRC::Common::strip_formatting($message);
    }

    # Match the first command like "!command"
    my $match = $message ~~ m/^(!\w+)/;
    # Put the command in the variable
    my $cmd = lc($1);

    # Command?
    if ($match) {
        # Yes so, compare different types of commands and return it to the sender
        my $result;

        # !pre release
        if ($cmd eq "!pre") {
            $match = $message ~~ m/^!\w+\s(\w.*)/;

            # Search for pre
            $self->searchPre($nick, $1);

        # !dupe bla bla bla
        } elsif ($cmd eq "!dupe") {
            $match = $message ~~ m/^!\w+\s(.*)/;

            # Search foo dupes
            $self->searchDupe($nick, $1);

        # !grp group
        } elsif ($cmd eq "!grp") {
            $match = $message ~~ m/^!\w+\s(.*)/;

            # Search foo dupes
            $self->group($nick, $1);

        # !new section
        } elsif ($cmd eq "!new") {
            $match = $message ~~ m/^!\w+\s(.*)/;

            # Search foo dupes
            $self->newest($nick, $1);

        # !help
        } elsif($cmd eq "!help") {
            $match = $message ~~ m/^!\w+\s(\w.*)/;

            # Search foo pre
            $self->searchHelp($nick);
        }
    }

    return $ZNC::CONTINUE;
}

##
# !pre
# !dupe 
##

# Search pre
# Param (nick, release)
sub searchPre {
    my $self = shift;
    my ($nick, $release) = @_;
    my $result;

    # Connect to Database
    my $dbh = DBI->connect("DBI:mysql:database=$DB_NAME;host=$DB_HOST", $DB_USER, $DB_PASSWD)
        or die "Couldn't connect to database: " . DBI->errstr;

    # Prepare Query -> Get Release
    my $query = $dbh->prepare("SELECT * FROM  `".$DB_TABLE."` WHERE `".$COL_RELEASE."` LIKE ? LIMIT 1;");

    # Execute Query
    $query->execute($release) or die $dbh->errstr;

    # Get rows
    my $rows = $query->rows();
    # Do we have a result?
    if ($rows > 0) {
        # set variables
        my ($id, $pretime, $pre, $section, $files, $size, $status, $reason, $group) = $query->fetchrow();
        $pretime = $self->get_time_since($pretime);
        $section = $self->getSection($section);

        # SECTION + RELEASE
        $result .= $section." ".$pre." ".$pretime;

        # FILES + SIZE?
        if ($files > 0 or $size > 0.00) {
            $result .= GREY." - [".NORMAL.$files.ORANGE."F".NORMAL." - ".$size.ORANGE."MB".GREY."] ".NORMAL;
        }

        # NUKED or DEL?
        if ($status eq 1 or $status eq 3) {
            $status = $self->getType($status);
            $result .= " - ".$status.RED.": ".$reason;
        }

    } else  {
        $result .= BOLD."Sorry!".NORMAL." Found nothing about '".BOLD.UNDERLINE.$release.NORMAL."'";
    }

    # Finish query
    $query->finish();

    # Disconnect Database
    $dbh->disconnect();

    # return result
    $self->sendMessage($nick, $result);
}

# Search dupe
# Param (nick, release)
sub searchDupe {
    my $self = shift;
    my ($nick, $param) = @_;
    my $release = "%".$param."%";
    my $result;

    # Replace whitespaces with % (for the SQL search query)
    if ($release ~~ m/\s+/) {
        $release =~ s/\s/%/g;
    }

    # Connect to Database
    my $dbh = DBI->connect("DBI:mysql:database=$DB_NAME;host=$DB_HOST", $DB_USER, $DB_PASSWD)
        or die "Couldn't connect to database: " . DBI->errstr;

    # Prepare Query -> Get Releases
    my $query = $dbh->prepare("SELECT * FROM  `".$DB_TABLE."` WHERE LOWER(`".$COL_RELEASE."`) LIKE LOWER( ? ) ORDER BY `".$COL_PRETIME."` DESC LIMIT 10;");

    # Execute Query
    $query->execute($release) or die $dbh->errstr;

    # Get rows
    my $rows = $query->rows();
    # Do we have results?
    if ($rows > 0) {
        # Less than 10 results? Return the results number
        if ($rows < 10) {
            $result = $rows > 1 ? "results": "result";
            $self->sendMessage($nick, "Found ".BOLD.UNDERLINE.$rows.NORMAL." ".$result." for '".BOLD.UNDERLINE.$param.NORMAL."'");
        } else {
            $self->sendMessage($nick, "Last 10 results for '".BOLD.UNDERLINE.$param.NORMAL."'");
        }

        # Get results
        my $i = 0;
        while ($i < $rows) {
            # reset result variable
            $result = "";
            # Set variables
            my ($id, $pretime, $pre, $section, $files, $size, $status, $reason, $group) = $query->fetchrow();
            $pretime = $self->get_time_since($pretime);
            $section = $self->getSection($section);

            # SECTION + RELEASE
            $result .= $section." ".$pre." ".$pretime;

            # FILES + SIZE?
            if ($files > 0 or $size > 0.00) {
                $result .= GREY." - [".NORMAL.$files.ORANGE."F".NORMAL." - ".$size.ORANGE."MB".GREY."] ".NORMAL;
            }

            # NUKED or DEL?
            if ($status eq 1 or $status eq 3) {
                $status = $self->getType($status);
                $result .= " - ".$status.RED.": ".$reason;
            }

            # Return result
            $self->sendMessage($nick, $result);
            $i++;
        }
    } else  {
        $self->sendMessage($nick, BOLD."Sorry!".NORMAL." Found nothing about '".BOLD.UNDERLINE.$param.NORMAL."'");
    }

    # Finish query
    $query->finish();

    # Disconnect Database
    $dbh->disconnect();
}

##
# !grp group
##

# Search grp releases
# Param (nick,group)
sub group {
    my $self = shift;
    my ($nick, $param) = @_;
    my $group = "%".$param."%";
    my $result;

    # Connect to Database
    my $dbh = DBI->connect("DBI:mysql:database=$DB_NAME;host=$DB_HOST", $DB_USER, $DB_PASSWD)
        or die "Couldn't connect to database: " . DBI->errstr;

    # Prepare Query -> Get group releases
    my $query = $dbh->prepare("SELECT * FROM  `".$DB_TABLE."` WHERE LOWER(`".$COL_GROUP."`) LIKE LOWER( ? ) ORDER BY `".$COL_PRETIME."` DESC LIMIT 0, 10;");

    # Execute Query
    $query->execute($group) or die $dbh->errstr;

    # Get rows
    my $rows = $query->rows();
    # Do we have results?
    if ($rows > 0) {
        # Less than 10 results? Return the results number
        if ($rows < 10) {
            $result = $rows > 1 ? "results": "result";
            $self->sendMessage($nick, "Found ".BOLD.UNDERLINE.$rows.NORMAL." ".$result." for '".GREEN.$param.NORMAL."'");
        } else {
            $self->sendMessage($nick, "Last 10 results for '".BOLD.UNDERLINE.$param.NORMAL."'");
        }

        # Get results
        my $i = 0;
        while ($i < $rows) {
            # reset result variable
            $result = "";
            # Set variables
            my ($id, $pretime, $pre, $section, $files, $size, $status, $reason, $group) = $query->fetchrow();
            $pretime = $self->get_time_since($pretime);
            $section = $self->getSection($section);

            # SECTION + RELEASE
            $result .= $section." ".$pre." ".$pretime;

            # FILES + SIZE?
            if ($files > 0 or $size > 0.00) {
                $result .= GREY." - [".NORMAL.$files.ORANGE."F".NORMAL." - ".$size.ORANGE."MB".GREY."] ".NORMAL;
            }

            # NUKED or DEL?
            if ($status eq 1 or $status eq 3) {
                $status = $self->getType($status);
                $result .= " - ".$status.RED.": ".$reason;
            }

            # Return result
            $self->sendMessage($nick, $result);
            $i++;
        }
    } else  {
        $self->sendMessage($nick, BOLD."Sorry!".NORMAL." Found nothing about '".BOLD.UNDERLINE.$param.NORMAL."'");
    }

    # Finish query
    $query->finish();

    # Disconnect Database
    $dbh->disconnect();
}

##
# !new section
# !day, !week, !month, !year
##

# Show the newest releases of a section.
# Param (nick, section)
sub newest {
    my $self = shift;
    my ($nick, $param) = @_;
    my $sec = "%".$param."%";
    my $result;

    # Replace whitespaces with % (for the SQL search query)
    if ($sec ~~ m/\s+/) {
        $sec =~ s/\s/%/g;
    }

    # Connect to Database
    my $dbh = DBI->connect("DBI:mysql:database=$DB_NAME;host=$DB_HOST", $DB_USER, $DB_PASSWD)
        or die "Couldn't connect to database: " . DBI->errstr;

    # Prepare Query -> Get newest section releases
    my $query = $dbh->prepare("SELECT * FROM `".$DB_TABLE."` WHERE LOWER(`".$COL_SECTION."`) LIKE LOWER( ? ) ORDER BY `".$COL_PRETIME."` DESC LIMIT 0, 10;");

    # Execute Query
    $query->execute($sec) or die $dbh->errstr;

    # Get rows
    my $rows = $query->rows();
    # Do we have results?
    if ($rows > 0) {
        $sec = uc($self->getSection($param));
        # Less than 10 results? Return the results number
        if ($rows < 10) {
            $result = $rows > 1 ? "results": "result";
            $self->sendMessage($nick, "Found ".BOLD.UNDERLINE.$rows.NORMAL." ".$result." for ".$sec);
        } else {
            $self->sendMessage($nick, "Last 10 results for ".$sec);
        }

        # Get results
        my $i = 0;
        while ($i < $rows) {
            # reset result variable
            $result = "";
            # Set variables
            my ($id, $pretime, $pre, $section, $files, $size, $status, $reason, $group) = $query->fetchrow();
            $pretime = $self->get_time_since($pretime);
            $section = $self->getSection($section);

            # SECTION + RELEASE
            $result .= $section." ".$pre." ".$pretime;

            # FILES + SIZE?
            if ($files > 0 or $size > 0.00) {
                $result .= GREY." - [".NORMAL.$files.ORANGE."F".NORMAL." - ".$size.ORANGE."MB".GREY."] ".NORMAL;
            }

            # NUKED or DEL?
            if ($status eq 1 or $status eq 3) {
                $status = $self->getType($status);
                $result .= " - ".$status.RED.": ".$reason;
            }

            # Return result
            $self->sendMessage($nick, $result);
            $i++;
        }
    } else  {
        $self->sendMessage($nick, BOLD."Sorry!".NORMAL." Found nothing about '".BOLD.UNDERLINE.$param.NORMAL."'");
    }

    # Finish query
    $query->finish();

    # Disconnect Database
    $dbh->disconnect();
}

##
# Basic functions
##

# Return the type with a color
# Param (type)
sub getType {
    my $self = shift;
    my $type = $_[0];
    my $color;

    # PRE
    if ($type ~~ m/0|2|4/) {
        $color .= GREEN."PRE";
    # UNNUKE / UNDELPRE / INFO
    } elsif ($type eq 1) {
        $color .= RED."NUKED";
    # NUKE / DELPRE
    } elsif ($type eq 3) {
        $color .= RED."DEL";
    } 

    return $color.NORMAL;
}

# Return the section with a color
# Param (section)
sub getSection  {
    my $self = shift;
    my $section = $_[0];
    my $color;

    # XXX
    if($section ~~ m/xxx|ima?ge?set/i) {
        $color = PINK;

    # TV Shows/Series: TV TV-BLURAY TV-DVDR TV-DVDRiP TV-HR TV-x264 TV-XViD
    } elsif ($section ~~ m/tv-?|doku/i) {
        $color = ORANGE;
 
    # Movies: DVDR / XVID / X264 / SVCD / VCD / BLURAY
    } elsif ($section ~~ m/dvdr|xvid|x264|vcd|divx|bluray/i) {
        $color = RED;

    # Console Games: NDS PS1 PS2 PS3 PS4 PSP PSX PSXPSP GAMECUBE GAMEBOY
    } elsif ($section ~~ m/ps[\dpx]|xbox|ngc|nds|gcn|wii|game(cube|boy)/i) {
        $color = TEAL;

    # Music Videos: MVID / MDVDR
    } elsif ($section ~~ m/mdvdr|mvid/i) {
        $color = LIGHT_BLUE;

    # Audio: MP3 / SAMPLE
    } elsif ($section ~~ m/mp3|sample|flac/i) {
        $color = LIGHT_GREEN;

    # ANIME
    } elsif ($section ~~ m/anime/i) {
        $color = PURPLE;

    # Books: EBOOK / AUDIOBOOK
    } elsif ($section ~~ m/[e|a].*book/i) {
        $color = GREEN;

    # PRE DOX PDA SUBPACK COVER
    } elsif ($section ~~ m/dox|pda|subpack|cover|font/i) {
        $color = LIGHT_CYAN;

    # APPS 0DAY MOBILE
    } elsif ($section ~~ m/apps|0day|mobile/i) {
        $color = BROWN;

    # GAMES
    } elsif ($section ~~ m/games/i) {
        $color = BLUE;

    # UNKOWN
    } else {
        $color = GREY;
    }

    return GREY."[".BOLD.$color.$section.NORMAL.GREY."]".NORMAL;
}

# Return time passed since a timestamp
# 1y 2m 27d 4h 5m 57s
# Param (timestamp)
sub get_time_since {
    my $self = shift;
    my $secs = time() - $_[0];
    my $time;

    # Set variables
    # YEARS
    if ($secs >= 31536000) {
        $time .= BOLD.int($secs / 31536000).NORMAL.GREY."y ";
        $secs = $secs % 31536000;
    }
    # MONTHS
    if ($secs >= 2628000) {
        $time .= BOLD.int($secs / 2628000).NORMAL.GREY."m ";
        $secs = $secs % 2628000;
    }
    # DAYS
    if ($secs >= 86400) {
        $time .= BOLD.int($secs / 86400).NORMAL.GREY."d ";
        $secs = $secs % 86400;
    }
    # HOURS
    if ($secs >= 3600) {
        $time .= BOLD.int($secs / 3600).NORMAL.GREY."h ";
        $secs = $secs % 3600;
    }
    # MINUTES
    if ($secs >= 60) {
        $time .= BOLD.int($secs / 60).NORMAL.GREY."m ";
        $secs = $secs % 60;
    }
    # SECONDS
    if ($secs >= 0) {
        $time .= BOLD.$secs.NORMAL.GREY."s";
    }

    return "- ".GREY."pred ".$time." ago".NORMAL;
}

# Return known commands
# Param (nick)
sub searchHelp {
    my $self = shift;
    my $nick = $_[0];

    # send known commands
    $self->sendMessage($nick, ORANGE.BOLD."Known commands:".NORMAL);
    # !pre release
    $self->sendMessage($nick, ORANGE.BOLD."!pre".NORMAL." release.name-group ".GREY."//".NORMAL." Search for specific release");
    # !dupe release
    $self->sendMessage($nick, ORANGE.BOLD."!dupe".NORMAL." release.name-group OR ".ORANGE.BOLD."!dupe ".NORMAL."bla bla bla ".GREY."//".NORMAL." Search for dupes");
    # !grp group
    $self->sendMessage($nick, ORANGE.BOLD."!grp".NORMAL." groupname ".GREY."//".NORMAL." Last 5 group releases");
    # !info group
    #$self->sendMessage($nick, ORANGE.BOLD."!info".NORMAL." groupname ".GREY."//".NORMAL." Group stats");
    # !new section
    $self->sendMessage($nick, ORANGE.BOLD."!new".NORMAL." section ".GREY."//".NORMAL." Last 10 section releases");
    # !top
    #$self->sendMessage($nick, ORANGE.BOLD."!top ".NORMAL.GREY."//".NORMAL." All-time Top 10 groups");
    # !top section
    #$self->sendMessage($nick, ORANGE.BOLD."!top".NORMAL." section ".GREY."//".NORMAL." Top 5 groups of a section");
    # !today, !week, !month, !year
    #$self->sendMessage($nick, ORANGE.BOLD."!today, !week, !month, !year ".GREY."//".NORMAL." Stats for a specific time period");
    # !stats
    #$self->sendMessage($nick, ORANGE.BOLD."!stats ".GREY."//".NORMAL." Extended DB stats");
    # !db
    #$self->sendMessage($nick, ORANGE.BOLD."!db ".GREY."//".NORMAL." Short DB stats");
    # !help
    $self->sendMessage($nick, ORANGE.BOLD."!help ".GREY."//".NORMAL." Known commands");
}

##
# IRC functions
##

# Send IRC message
# Param (nick, message)
sub sendMessage {
    my $self = shift;
    my ($nick, $message) = @_;

    # Brackets before and after the message
    $message = GREY."< ".NORMAL.$message.GREY." >";

    # send private message
    $self->PutIRC("PRIVMSG ".$nick." : ".$message);
}

1;