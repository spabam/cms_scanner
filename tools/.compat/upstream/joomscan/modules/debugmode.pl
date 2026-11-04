# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
#start Debug Mode Checker

$source=$ua->get("$target/")->decoded_content;
if ($source =~ /Joomla\! Debug Console/g or $source =~ /xdebug\.org\/docs\/all_settings/g) {
	dprint("Checking Debug Mode status");
	tprint("Debug mode Enabled : $target/");
}

#end Debug Mode Checker
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
