#!/system/bin/sh

# instruct the system to run fstrim
am broadcast -a android.intent.action.ACTION_IDLE_MAINTENANCE_START

