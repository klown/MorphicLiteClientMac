#!/bin/sh

#  Copyright 2020 Raising the Floor - International
#  Copyright 2020 OCAD University
#
#  Licensed under the New BSD license. You may not use this file except in
#  compliance with this License.
#
#  You may obtain a copy of the License at
#  https://github.com/GPII/universal/blob/master/LICENSE.txt
#
#  The R&D leading to these results received funding from the:
#  * Rehabilitation Services Administration, US Dept. of Education under
#    grant H421A150006 (APCP)
#  * National Institute on Disability, Independent Living, and
#    Rehabilitation Research (NIDILRR)
#  * Administration for Independent Living & Dept. of Education under grants
#    H133E080022 (RERC-IT) and H133E130028/90RE5003-01-00 (UIITA-RERC)
#  * European Union's Seventh Framework Programme (FP7/2007-2013) grant
#    agreement nos. 289016 (Cloud4all) and 610510 (Prosperity4All)
#  * William and Flora Hewlett Foundation
#  * Ontario Ministry of Research and Innovation
#  * Canadian Foundation for Innovation
#  * Adobe Foundation
#  * Consumer Electronics Association Foundation

MORPHIC="Morphic.app"
ADD_MESSAGE="Adding Morphic to Dock"
ALREADY_MESSAGE="Morphic already in Dock"

log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Start `basename $0`"

defaults read com.apple.dock persistent-apps | grep "${MORPHIC}" > /dev/null
if [ $? != "0" ]
then
    log "$ADD_MESSAGE"
    defaults write com.apple.dock persistent-apps -array-add \
    "<dict>
        <key>tile-data</key>
        <dict>
            <key>file-data</key>
            <dict>
                <key>_CFURLString</key>
                <string>/Applications/${MORPHIC}/</string>
                <key>_CFURLStringType</key>
                <integer>0</integer>
            </dict>
        </dict>
    </dict>" && killall "Dock"
else
    log "$ALREADY_MESSAGE"
fi

log "`basename $0` complete"
