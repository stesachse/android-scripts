#!/system/bin/sh

# zeigt folgendes
# 1. spalte: load avg
# 2. spalte: anzahlt der aktiven CPUs
# 3. spalte: die aktuelle frequenz von cpu0

# keine nicht definierten variablen
# set -u
set -o nounset

# read only
# den pfad entfernen /foo/bar/script.sh
typeset -r SCRIPTNAME=${0##*/}

typeset OPT_VERBOSE=${VERBOSE:+yes}
typeset OPT_DEBUG=${DEBUG:+yes}
typeset OPT_DELAY=1

usage ()
{
        cat << EOF
$SCRIPTNAME [OPTIONS]

Zeig spaltenweise verschiedene CPU und Lastwerte an.

Options:

 *** note: If the option has an optional argument, it must be written
     directly after the option character if present
     ex: -oValueOptional or --option=ValueOptional ***

 -s, -stats        zeigt fortlaufend die CPU Statistiken an
 -l x, -delay x    aller x sekunden Werte ausgeben (default: $OPT_DELAY)
 -n, -one-header   die Kopfzeile mit den Einstellungen nur einmalig
                   anzeigen anstatt periodisch
 -v, -verbose      mehr Ausgaben (env var: VERBOSE)
 -d, -debug        noch mehr Ausgaben als -verbose (env var: DEBUG)
 -h, -help         Hilfetext
EOF
}

echo_stderr ()  { echo        "$@" >&2 ; }
echo_error ()   { echo_stderr "# ERROR   # $@" ; }
echo_verbose () { [[ $OPT_VERBOSE || $OPT_DEBUG ]] && echo_stderr "# VERBOSE # $@" ; }
echo_debug ()   { [[ $OPT_DEBUG ]]   && echo_stderr "# DEBUG   # $@" ; }

# fix: "$@: unbound variable"
if [[ $# -eq 0 ]] ; then
        eval set -- "--"
fi

# read only
# -o 'options' If the first character is a '-', non-option parameters
#              are outputted at the place where they are found in
#              normal operation, they are all collected at the end of
#              output after a '--' parameter has been  generated
#    :   required argument
#    ::  optional argument
#
# example: -o '-ho::r:'
#  -   -> non-option where they are found
#  h   -> option -h
#  o:: -> option -o with optional argument
#  r:  -> option -r with required argument
OPTIONS_QUOTED=$(getopt -n "${SCRIPTNAME%.*}" -a -o '-vdhsl:no::r:' -l 'verbose,debug,help,stats,delay:,one-header,optional::,required:' -- "$@")
RETVAL=$?
if [[ $RETVAL -ne 0 ]] ; then
	echo_stderr

        # fehler beim parsen der vom user angegebenen optionen
        if [[ $RETVAL -eq 1 ]] ; then
                echo_stderr "can not parse options!"
                echo_stderr
                usage >&2
                exit $RETVAL
        fi

        # fehler bei den getopt optionen
        if [[ $RETVAL -eq 2 ]] ; then
                echo_stderr "calling getopt with wrong options!"
                exit $RETVAL
        fi

        # getopt internal error like out-of-memory
        if [[ $RETVAL -eq 3 ]] ; then
                echo_stderr "getopt internal error!"
                exit $RETVAL
        fi

        # calling getopt -T
        [[ $RETVAL -eq 4 ]] && exit 1

        echo_stderr "unknown getopt return code: $RETVAL"
        exit 1
fi
typeset -r OPTIONS_QUOTED

eval set -- "$OPTIONS_QUOTED"

typeset -a OPTIONS_NON_OPTIONS
OPTIONS_NON_OPTIONS=()

typeset OPT_REQUIRED=
typeset OPT_OPTIONAL=
typeset OPT_STATS=
typeset OPT_ONE_HEADER=
while [ $# -gt 0 ]
do
        case "$1" in
		--stats | -s )
			OPT_STATS=yes
			shift
		;;

		--delay | -l )
			OPT_DELAY=$2
			shift 2
		;;

		--one-header | -n )
			OPT_ONE_HEADER=yes
			shift
		;;

                --verbose | -v )
                        OPT_VERBOSE=yes
                        shift
                ;;

                --debug | -d )
                        OPT_DEBUG=yes
                        shift
                ;;

                --help | -h )
                        usage
                        exit 0
                ;;
                
                # option mit einem erforderlichen argument
                --required | -r )
                        OPT_REQUIRED=$2
                        shift 2
                ;;

                # option mit einem optionalen argument
                # $2 ist leer wenn nichts angegeben wurde
                --optional | -o )
                        OPT_OPTIONAL=$2
                        shift 2
                ;;

                # stop parsing
                --) shift; break;;

                # non option parameters
                *)
                        OPTIONS_NON_OPTIONS+=("$1")
                        shift
                ;;
        esac
done

# make it read only
typeset -r OPTIONS_NON_OPTIONS

# readonly
# weil es sich vllt manchmal einfach besser behandeln laesst
typeset -a OPTIONS_ARGV
OPTIONS_ARGV=("$@")
typeset -r OPTIONS_ARGV


##
## YOUR SCRIPT STARTS HERE
##

# die gesetzten optionen im beispiel
echo_debug   "            \$COLUMNS: ${COLUMNS}"
echo_debug   "              \$LINES: ${LINES}"
echo_verbose "          \$OPT_STATS: ${OPT_STATS}"
echo_verbose "          \$OPT_DELAY: ${OPT_DELAY}"
echo_verbose "     \$OPT_ONE_HEADER: ${OPT_ONE_HEADER}"

# alles was an nicht optionen vor dem -- (stop parsing options) kam
# befindet sich im readonly array $OPTIONS_NON_OPTIONS
echo_verbose "\$OPTIONS_NON_OPTIONS: array with ${#OPTIONS_NON_OPTIONS[@]} element(s)"
typeset -i idx=0
typeset -i cnt=${#OPTIONS_NON_OPTIONS[@]}
while [[ $idx -lt $cnt ]] ; do
	echo_verbose "                      $idx: ${OPTIONS_NON_OPTIONS[$idx]}"
	(( let idx++ ))
done

# alles was nach dem -- (stop parsing options) kam bleibt wie
# ueblich in $* und $@ fuer eventuelles besseres handling
# steht es nochmal im readonly array $OPTIONS_ARGV
echo_verbose " remaining args (\$@): $#"
typeset -i idx=0
typeset -i cnt=${#OPTIONS_ARGV[@]}
while [[ $idx -lt $cnt ]] ; do
	echo_verbose "                      $idx: ${OPTIONS_ARGV[$idx]}"
	(( let idx++ ))
done

print_settings()
{
	typeset cpu_num_min="$(cat /sys/devices/system/cpu/cpuquiet/tegra_cpuquiet/min_cpus)"
	typeset cpu_num_max="$(cat /sys/devices/system/cpu/cpuquiet/tegra_cpuquiet/max_cpus)"
	typeset cpu_num_off="$(cat /sys/module/cpu_tegra/parameters/suspend_cap_cpu_num)"
	typeset   freq_min="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)"
	typeset   freq_max="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)"
	typeset freq_audio="$(cat /sys/module/snd_soc_tlv320aic3008/parameters/audio_min_freq)"
	typeset   freq_off="$(cat /sys/module/cpu_tegra/parameters/suspend_cap_freq)"
	typeset  gov_scale="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
	typeset  gov_quiet="$(cat /sys/devices/system/cpu/cpuquiet/current_governor)"

	# frequenzen in Mhz statt Hz
	typeset varname
	for varname in freq_min freq_max freq_audio freq_off ; do
		# erzeugt eine referenz auf die var mit dem name $varname
		typeset -n var_ref=$varname
		(( var_ref = var_ref / 1000 ))
	done

	echo "freq|${freq_min}-${freq_max} audio:${freq_audio} off:${freq_off}" \
		"cpu|${cpu_num_min}-${cpu_num_max} off:${cpu_num_off}" \
		"gov|${gov_scale} quiet:${gov_quiet}"
}

typeset cpu_stats_offline_msg="-"
typeset -i loop_count=0
print_settings
while : ; do
	(( loop_count++ ))

	load_avg="$(cat /proc/loadavg)"
	cpu_num_active="$(cat /sys/devices/system/cpu/cpu_on)"

	# frequenzen der cpus einsammeln
	cpu_stats=
	cpu_stats_sep=
	for cpu_dir in /sys/devices/system/cpu/cpu[0-9]/ ; do
		# cpu number from path
		cpu_stats_num="${cpu_dir%/}"		# remove / at the end
		cpu_stats_num="${cpu_stats_num##*/}"	# last part of the dir
		cpu_stats_num="${cpu_stats_num##cpu}"	# only keep the numbers at then end

		cpu_stats_freq="$(cat ${cpu_dir}/cpufreq/scaling_cur_freq 2>/dev/null)"
		if [[ $? -ne 0 ]] ; then
			# cpu ist offline
			cpu_stats_freq="${cpu_stats_offline_msg}"
		else
			# frequenz in MHz statt Hz
			(( cpu_stats_freq = cpu_stats_freq / 1000 )) # 1700
		fi

		cpu_stats+=${cpu_stats_sep}
		cpu_stats+="$(command printf "cpu%d:%-4s" "${cpu_stats_num}" "${cpu_stats_freq}")"

		cpu_stats_sep=" | "
	done
	
	# den settings header ausgeben
	typeset mymodulo=-1
	while : ; do
		# wir haben -one-header
		if [[ $OPT_ONE_HEADER ]] ; then
			break
		fi

		# ist es soweit was auszugeben?
		(( mymodulo = (loop_count) % (LINES - 2) ))
		if [[ $mymodulo != 0 ]] ; then
			break;
		fi

		print_settings

		if [[ $loop_count > 10000 ]] ; then
			loop_count=0
		fi
		break
	done

	# ausgeben
	command printf "load: %-14s | on:%s | ${cpu_stats}\n" \
		"${load_avg:0:14}" \
		"${cpu_num_active}"

	# wir wollen nicht fortlaufend sehen
	if [[ ! $OPT_STATS && $loop_count > 0 ]] ; then
		echo_debug "exit: because no -stats given and \$loop_count=${loop_count}"
		break
	fi

	sleep $OPT_DELAY
done

