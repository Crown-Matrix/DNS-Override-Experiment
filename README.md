# How to use

1. Obtain a domains.txt, you can either use one yourself(which domains you want to check to see if they're blocked), or use ```get_domains.sh``` to generate one (should take ~20 seconds)
    + theres another scripts to for alternatives to generating a domains.txt in ```/dev (build domains.txt)```

2. Once you have one, use ```check_verbose.sh``` in ```/main (use domains.txt)``` to build your log file of all domains restricted on ur DNS config spotting them with "FAILED REFUSED". it doesnt have to be in one sitting, just on the same wifi context. it will by default use your domains.txt from step 1.
    + The name of your log file being built is configured via ```current_log.txt```(must be 1 line), you can use ```grep -r current_log.txt``` to see what its used for if you are familiar with shellscript.

3. you can also watch the progress with progress_counter.sh in another terminal

4. once you have the complete file feed it to auto_dns_override.sh which will place the new DNS config into ur computer to reroute all REFUSED domains to a more reliable source.