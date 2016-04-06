####################################################################################
#  Timed ban with a change to escape it by guessing the right code phrase
#
#  To start the timed ban a user must type:
#    !troll <nickname>
#  Selecting the code phrase is done by typing:
#    !code <codephrase>
#
#  The codes you can choose from are displayed when the ban is activated.
#  This script will not allow bots (Users who are +b), or the bot running the
#  script, or friends of the bot (+g flag needed) to be banned.
#
#  (C) 2016 ArNz|8o8 - Based on timebomb.tcl by http://radiosaurus.sporkism.org
#  Made for eggdrop 1.6.x and up (Tested on CVS1.8.0/TCL8.6)
#
#  Version 1.4 beta - Added a stop when someone parts the channel during a troll.
#                     Thanks to Skxawng and Mio (from #fusion, Undernet) for
#                     noticing this.
#                     Fixed the chanflag so it acctually works (bah fast fixing)
#
#  Version 1.3 beta - Added Channel flag. For use: .chanset #channel +troll
#
#  Version 1.2 beta - Changed the banmask and added a ban duration
#                     Ban duration is set at theBanDuration in minutes
#                     More code cleaned
#
#  Version 1.1 beta - Stable release, working as intented
#
#  Version 1.0 beta - First working release, code cleaned up
#
####################################################################################

# Set channel flag to troll
# You must set +troll on your desired channel(s)
#

setudef flag troll

# Binds

bind pub  - !troll doCodeBan
bind pub  - !code  doCrackCode
bind part - *      doTargetLeft

# Configuration

set theBanDuration 15
set gGetCodeMinDuration 30
set gGetCodeMaxDuration 50
set gCodePhrases "x7WRPJeK 58fG4P4A 3m4289uQ QPcj5QmJ 5u928AEB h5cfA68C CAbKJ9Mm 2GY6dc9y 2GY6dc9y 7msVjxcM 7xeAvSne 77u29R5N pJJr6a4S bWG7GnQQ 779ZyraS AR57qU4b 7D5zFXVF YUH2KQvq FZ462f5Dv R2c75Zpx eh9CtNUq 3Z85VgpQ sVyW2dtf gxJ2TyaW gzU4VGCn 5ttf7QjU 6j6Feb5Z 2TH57saY JdEHCD5b r65334Mf eTEVGR3B 7HmJJ4vZ 74d56S8R"
set gMinCodeCount 2
set gMaxCodeCount 5

# Internal Globals

set gTheScriptVersion "1.4 beta - 8o8"
set gTimedBanActive 0
set gTimerId 0
set gTimedBanTarget ""
set gTimedBanChannel ""
set gCorrectCode ""
set gNumberNames "zero one two three four five six seven eight nine ten eleven twelve"

proc note {msg} {
  putlog "Timed Ban: $msg"
}

proc IRC8o8Ban {theNick theChannel theReason} {
global theBanDuration banmask botnick
set banmask "*![lindex [split [getchanhost $theNick] @] 0]@[lindex [split [getchanhost $theNick] @] 1]"
note "Banning $theNick in $theChannel (Reason: $theReason)"
newchanban $theChannel $banmask $botnick $theReason $theBanDuration
putquick "KICK $theChannel $theNick :$theReason"
putserv "PRIVMSG $theChannel :\001ACTION did gave $theNick a change.. $theBanDuration mins ban.\001"
return 1

}

proc IRCPrivMSG {theChannel messageString} {
  putserv "PRIVMSG $theChannel :$messageString"
}

proc IRCAction {theChannel messageString} {
  putserv "PRIVMSG $theChannel :\001ACTION $messageString\001"
}

proc MakeEnglishList {theList} {
  set theListLength [llength $theList]
  set returnString [lindex $theList 0]
  for {set x 1} {$x < $theListLength} {incr x} {
    if { $x == [expr $theListLength - 1] } {
      set returnString "$returnString and [lindex $theList $x]"
    } else {
      set returnString "$returnString, [lindex $theList $x]"
    }
  }
  return $returnString
}

proc SelectCodes {codeCount} {
  global gCodePhrases
  set totalcodeCount [llength $gCodePhrases]
  set selectedCodes ""
  for {set x 0} {$x < $codeCount} {incr x} {
    set currentCode [lindex $gCodePhrases [expr int( rand() * $totalcodeCount )]]
    if { [lsearch $selectedCodes $currentCode] == -1 } {
      lappend selectedCodes $currentCode
    } else {
      set x [expr $x - 1]
    }
  }
  return $selectedCodes
}

proc ActivateTimedBan {destroyTimer kickMessage} {
  global gTimedBanTarget gTimerId gTimedBanChannel gTimedBanActive
  if { $destroyTimer } {
    killutimer $gTimerId
  }
  set gTimerId 0
  set gTimedBanActive 0
  IRC8o8Ban $gTimedBanTarget $gTimedBanChannel $kickMessage
}

proc doTargetLeft {nickname hostname handle theChannel reason} {
  global gTimedBanTarget gTimerId gTimedBanChannel gTimedBanActive
  if { $gTimedBanActive == 0 } {
  # note "Someone left the Channel. No !troll was used"
  return 0
  } else {
  killutimer $gTimerId
  set gTimerId 0
  set gTimedBanActive 0
  note "Target $gTimedBanTarget left. Troll stopped"
  IRCPrivMSG $theChannel "Ahw, $gTimedBanTarget left.. Let's troll again upon returning!"
  }
}

proc CodeCracked {wireCut} {
  global gTimerId gTimedBanActive gTimedBanTarget gTimedBanChannel
  killutimer $gTimerId
  set gTimerId 0
  set gTimedBanActive 0
  IRCPrivMSG $gTimedBanChannel "$gTimedBanTarget dodged the ban there... Be cool now, ok?"
}

proc StartTimedBan {theStarter theNick theChannel} {
  global gTimedBanActive gTimedBanTarget gTimerId gTimedBanChannel gNumberNames gCorrectCode
  global gMaxCodeCount gGetCodeMinDuration gGetCodeMaxDuration
  if { $gTimedBanActive == 1 } {
    note "Timed ban not started for $theStarter (Reason: timed ban already active)"
    if { $theChannel != $gTimedBanChannel } {
      IRCPrivMSG $theChannel "No time to ban atm.. sorry."
    } else {
      IRCAction $theChannel "points at the ban on $gTimedBanTarget's ass."
    }
  } else {
    set timerDuration [expr $gGetCodeMinDuration + [expr int(rand() * ($gGetCodeMaxDuration - $gGetCodeMinDuration))]]
    set gTimedBanTarget $theNick
    set gTimedBanChannel $theChannel
    set numberOfCodes [expr 1 + int(rand() * ( $gMaxCodeCount - 0 ))]
    set listOfCodes [SelectCodes $numberOfCodes]
    set gCorrectCode [lindex $listOfCodes [expr int( rand() * $numberOfCodes )]]
    set CodeListAsEnglish [MakeEnglishList $listOfCodes]
    set codeCountAsEnglish [lindex $gNumberNames $numberOfCodes]
    IRCPrivMSG $theChannel "Well, $gTimedBanTarget, your number has come up. You are about to get banned, but..."
    if { $numberOfCodes == 1 } {
      IRCPrivMSG $theChannel "You get a change to undo this.. Get the right code in $timerDuration seconds."
      IRCPrivMSG $theChannel "Use !code <codephrase> for entering the codephrase. Lucky for you, the code phrase is $CodeListAsEnglish"
    } else {
      IRCPrivMSG $theChannel "You get a change to undo this.. Get the right code in $timerDuration seconds."
      IRCPrivMSG $theChannel "Use !code <codephrase> for entering the right codephrase. Code phrase options are: $CodeListAsEnglish"
    }
    note "Timed ban started by $theStarter (Troll ban handed to $theNick, I will ban in $timerDuration seconds)"
    set gTimedBanActive 1
    set gTimerId [utimer $timerDuration "ActivateTimedBan 0 {No guesses, no nothing... Banned anyways!}"]
  }
}

# Eggdrop command binds

proc doCrackCode {nick uhost hand channel arg} {
  global gTimedBanActive gCorrectCode gTimedBanTarget
  if { $gTimedBanActive == 1 } {
    if { [string tolower $nick] == [string tolower $gTimedBanTarget] } {
      if { [llength $arg] == 1 } {
        if { [string tolower $arg] == [string tolower $gCorrectCode] } {
          CodeCracked $gCorrectCode
        } else {
          IRCPrivMSG $channel "Ha!"
          ActivateTimedBan 1 "ahwww... BANNED!"
        }
      }
    }
  }
}

proc doCodeBan {nick host handle channel testes} {
if {[lsearch -exact [channel info $channel] +troll] != -1} {
global botnick
proc gethandle {nick} {
set host [getchanhost $nick]
set handle [finduser "*!$host"]
return $handle
}
set why [lrange $testes 1 end]
set who [lindex $testes 0]
set ban [maskhost [getchanhost $who $channel]]
if {[string tolower $who] == [string tolower $botnick]} {
putserv "MODE $channel -o $nick"
putserv "PRIVMSG $channel :Think that's funny? Trying to make me trick myself?"
return 1
}
if {$who == ""} {
putserv "PRIVMSG $channel :Ahum, it's !troll <nick to trick>"
return 1
}
set hand [gethandle $who]
if {[matchattr $hand +n|n]} {
putserv "MODE $channel -o $nick"
putserv "PRIVMSG $channel :I can't go around and ban my owner!"
return 1
}
set hand [gethandle $who]
if {[matchattr $hand +g|g]} {
putserv "MODE $channel -o $nick"
putserv "PRIVMSG $channel :I will not ban $who, it's a friend.."
return 1
}
if {![onchan $who $channel]} {
putserv "PRIVMSG $channel :I don't see $who on $channel"
return 1
}
set theNick $who
StartTimedBan $nick $theNick $channel
return 1
}
}

# End of Script - ArNz|8o8

note "Timed Code ban $gTheScriptVersion by ArNz|8o8 loaded";
note "with $gMaxCodeCount codes maximum, ban is for $theBanDuration minutes."
note "Time range of $gGetCodeMinDuration to $gGetCodeMaxDuration seconds.";
