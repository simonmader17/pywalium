#!/bin/bash

source ~/.cache/wal/colors.sh

dir="$(dirname "${BASH_SOURCE[0]}")"
dye_dir="$dir/dyetide"
theme_dir="$dir/pywalium-theme"

##################################################
# Turns "rgb(r, g, b)" into "r, g, b".
# GLOBALS:
# ARGUMENTS:
#   rgb string to trim
# OUTPUTS:
#   trimmed rgb string
# RETURN:
#   0 if trimming succeeds, non-zero on error
##################################################
trim_rgb() {
	if [[ ! "$1" =~ ^rgb(.*)$ ]]; then 
		echo "String to trim must be of format \"rgb(r, g, b)\""
		return 1
	fi
	echo "$1" | sed "s/rgb(\(.*\))/\1/"
}

##################################################
# Turns "hsl(h, s, l)" into "h, s, l".
# GLOBALS:
# ARGUMENTS:
#   hsl string to trim
# OUTPUTS:
#   trimmed hsl string
# RETURN:
#   0 if trimming succeeds, non-zero on error
##################################################
trim_hsl() {
	if [[ ! "$1" =~ ^hsl(.*)$ ]]; then 
		echo "String to trim must be of format \"hsl(h, s, l)\""
		return 1
	fi
	echo "$1" | sed "s/hsl(\(.*\))/\1/"
}

dec_to_float() {
	echo "scale=8; $1 / 255" | bc -l
}

find_min_max() {
	min=$1
	max=$1
	for arg in "$@"; do
		(( $(echo "$arg $min" | awk '{print ($1 < $2)}') )) && min="$arg"
		(( $(echo "$arg $max" | awk '{print ($1 > $2)}') )) && max="$arg"
	done
	return 0
}

clamp_min_max() {
	if (( $(echo "$1 $3" | awk '{print ($1 > $2)}') )); then
		echo "$3"
	elif (( $(echo "$1 $2" | awk '{print ($1 < $2)}') )); then
		echo "$2"
	else
		echo "$1"
	fi
}

##################################################
# Turns "#RRGGBB" into "rgb(r, g, b)".
# ARGUMENTS:
#   hex string
# OUTPUTS:
#   rgb string
##################################################
hex_to_rgb() {
	local hex=$(echo "$1" | tr -d "#")
	local r=$(( 16#${hex:0:2} ))
	local g=$(( 16#${hex:2:2} ))
	local b=$(( 16#${hex:4:2} ))
	echo "rgb($r, $g, $b)"
}

##################################################
# Turns "rgb(r, g, b)" into "hsl(h, s, l)".
# ARGUMENTS:
#   rgb string
# OUTPUTS:
#   hsl string
##################################################
rgb_to_hsl() {
	local trimmed_rgb dec_r dec_g dec_b r g b h s l
	trimmed_rgb="$(trim_rgb "$1")"
	dec_r=$(echo "$trimmed_rgb" | tr -d " " | cut -d "," -f 1)
	dec_g=$(echo "$trimmed_rgb" | tr -d " " | cut -d "," -f 2)
	dec_b=$(echo "$trimmed_rgb" | tr -d " " | cut -d "," -f 3)
	r=$(dec_to_float "$dec_r")
	g=$(dec_to_float "$dec_g")
	b=$(dec_to_float "$dec_b")

	find_min_max "$r" "$g" "$b"

	if (( $(echo "$min $max" | awk '{print ($1 == $2)}') )); then
		# greyscale
		h=0
		s=0
		# l="$(echo "scale=8; $min * 100" | bc -l)"
		l="$min"
	else
		# not greyscale
		delta="$(echo "scale=8; $max - $min" | bc -l)"

		# calculate hue
		if (( $(echo "$r $max" | awk '{print ($1 == $2)}') )); then
			h="$(echo "scale=8; ($g - $b) / $delta" | bc -l)"
			if (( $(echo "$g $b" | awk '{print ($1 < $2)}') )); then
				h="$(echo "scale=8; $h + 6" | bc -l)"
			fi
		elif (( $(echo "$g $max" | awk '{print ($1 == $2)}') )); then
			h="$(echo "scale=8; ($b - $r) / $delta + 2" | bc -l)"
		else
			h="$(echo "scale=8; ($r - $g) / $delta + 4" | bc -l)"
		fi
		h="$(echo "scale=8; $h / 6" | bc -l)"

		# calculate lightness
		l="$(echo "scale=8; ($min + $max) / 2" | bc -l)"

		# calculate saturation
		if (( $(echo "$l 0.5" | awk '{print ($1 > $2)}') )); then
			s="$(echo "scale=8; $delta / (2 - $min - $max)" | bc -l)"
		else
			s="$(echo "scale=8; $delta / ($min + $max)" | bc -l)"
		fi
	fi

	h="$(printf "%.0f" "$(echo "$h * 360" | bc -l)")"
	s="$(printf "%.0f" "$(echo "$s * 100" | bc -l)")"
	l="$(printf "%.0f" "$(echo "$l * 100" | bc -l)")"

	# clamp values
	h="$(clamp_min_max "$h" 0 360)"
	s="$(clamp_min_max "$s" 0 100)"
	l="$(clamp_min_max "$l" 0 100)"

	echo "hsl($h, $s%, $l%)"
}

# helper function used to determine rgba values in hsl_to_rgb                   
hue_to_rgb() {                                                                  
    # p=mid, q=chroma, t=hue                                                    
    local p=$1                                                                  
    local q=$2                                                                  
    local t=$3                                                                  
                                                                                
    # keeps value of hue between 0 and 1                                        
    if [[ $(echo "$t < 0" | bc -l) -eq 1 ]]; then                               
        t=$(echo "scale=8; $t + 1" | bc -l)                                                             
    fi                                                                          
    if [[ $(echo "$t > 1" | bc -l) -eq 1 ]]; then                               
        t=$(echo "scale=8; $t - 1" | bc -l)                                     
    fi                                                                          
                                                                                
    # depending on calculation of hue in hsl_to_rgb, $p is returned as value for
    # r,g,b based off of calculated angle of $t                                 
    if [[ $(echo "$t <= 1 / 6" | bc -l) -eq 1 ]]; then                          
        p=$(echo "scale=8; $p + ($q - $p) * 6 * $t" | bc -l)                    
        echo "$p"                                                               
        exit 0                                                                  
    elif [[ $(echo "$t < 1 / 2" | bc -l) -eq 1 ]]; then                         
        p=$q                                                                    
        echo "$p"                                                               
        exit 0                                                                  
    elif [[ $(echo "$t < 2 / 3" | bc -l) -eq 1 ]]; then                         
        p=$(echo "scale=8; $p + ($q - $p) * (2 / 3 - $t) * 6" | bc -l)          
        echo "$p"                                                               
        exit 0                                                                  
    fi                                                                          
                                                                                
    echo "$p"                                                                   
}

##################################################
# Turns "hsl(h, s, l)" into "rgb(r, g, b)".
# ARGUMENTS:
#   hsl string
# OUTPUTS:
#   rgb string
##################################################
hsl_to_rgb() {
	local trimmed_hsl h s l r g b
	trimmed_hsl="$(trim_hsl "$1")"
	h=$(echo "$trimmed_hsl" | tr -d " " | cut -d "," -f 1)
	s=$(echo "$trimmed_hsl" | tr -d " " | cut -d "," -f 2 | tr -d "%")
	l=$(echo "$trimmed_hsl" | tr -d " " | cut -d "," -f 3 | tr -d "%")

	h="$(echo "scale=8; $h / 360" | bc -l)"
	s="$(echo "scale=8; $s / 100" | bc -l)"
	l="$(echo "scale=8; $l / 100" | bc -l)"

	if [[ $s -eq 0 ]] 2>/dev/null; then
		# greyscale
		r="$(printf "%.0f" "$(echo "$l * 255" | bc -l)")"
		g="$r"
		b="$r"
	else
		local q p                                                               
        # determine chroma value based off of lightness value                   
        if (( $(echo "$l 0.5" | awk '{print ($1 < $2)}') )); then               
            q=$(echo "scale=8; $l * (1 + $s)" | bc -l)                          
        else                                                                    
            q=$(echo "scale=8; $l + $s - $l * $s" | bc -l)                      
        fi                                                                      
                                                                                
        # mid is calculated based off of lightness and chroma values            
        p=$(echo "scale=6; 2 * $l - $q" | bc -l)                                
        # determines r,g,b values based off of hue's orientation to 360 degree color wheel
        r=$(hue_to_rgb "$p" "$q" "$(echo "$h" | awk '{print $1 + (1 / 3)}')")   
        g=$(hue_to_rgb "$p" "$q" "$h")                                          
        b=$(hue_to_rgb "$p" "$q" "$(echo "$h" | awk '{print $1 - (1 / 3)}')") 

		r="$(printf "%.0f" "$(echo "$r * 255" | bc -l)")"
		g="$(printf "%.0f" "$(echo "$g * 255" | bc -l)")"
		b="$(printf "%.0f" "$(echo "$b * 255" | bc -l)")"

		r="$(clamp_min_max "$r" 0 255)"
		g="$(clamp_min_max "$g" 0 255)"
		b="$(clamp_min_max "$b" 0 255)"
	fi

	echo "rgb($r, $g, $b)"
}

##################################################
# Increase lightness of given hsl value by a given
# percentage.
# ARGUMENTS:
#   hsl string
#   percentage
# OUTPUTS:
#   hsl string
##################################################
lighten() {
	hsl="$(rgb_to_hsl "$1")"
	l="$(echo "$hsl" | grep -o -P '\d*' | tail -1)"
	new_l="$(( $l + (100 - $l) * $2 / 100 ))"
	new_hsl="$(echo "$hsl" | sed "s/\(.*\)$l/\1$new_l/")"
	new_rgb="$(hsl_to_rgb "$new_hsl")"
	echo "$new_rgb"
}

bg=$(trim_rgb "$(hex_to_rgb "$background")")
bg_light=$(trim_rgb "$(lighten "$(hex_to_rgb "$background")" 12)")
bg_lighter=$(trim_rgb "$(lighten "$(hex_to_rgb "$background")" 24)")
fg=$(trim_rgb "$(hex_to_rgb "$foreground")")
accent=$(trim_rgb "$(hex_to_rgb "$color2")")

[ -d "$theme_dir" ] && rm -rf "$theme_dir"
mkdir "$theme_dir"
cat > "$theme_dir/manifest.json" << EOF
{
	"manifest_version": 2,
	"version": "1.0",
	"name": "Pywalium Theme",
	"theme": {
		"colors": {
			"background_tab": [$bg],
			"background_tab_inactive": [$bg],
			"bookmark_text": [$fg],
			"button_background": [$bg],
			"frame": [$bg],
			"frame_inactive": [$bg],
			"ntp_background": [$bg],
			"ntp_header": [$bg_light],
			"ntp_link": [$accent],
			"ntp_text": [$fg],
			"omnibox_background": [$bg_lighter],
			"omnibox_text": [$fg],
			"omnibox_text_inactive": [$fg],
			"tab_background_text": [$fg],
			"tab_background_text_inactive": [$fg],
   			"tab_text": [$fg],
   			"toolbar": [$bg_light],
   			"toolbar_button_icon": [$accent],
   			"toolbar_text": [$fg]
		}
	}
}
EOF

# Incognito mode colors:
# "background_tab_incognito": [$fg],
# "background_tab_incognito_inactive": [$fg],
# "frame_incognito": [$fg],
# "frame_incognito_inactive": [$fg],
# "omnibox_text_incognito": [$bg],
# "omnibox_text_incognito_inactive": [$bg],
# "tab_background_text_incognito": [$bg],
# "tab_background_text_incognito_inactive": [$bg]

echo "Pywalium Theme generated:"
cat "$theme_dir/manifest.json"
