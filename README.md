# scripts

I can't fully vouch for the quality of these scripts,
which were generated with AI chatbot assistance. If
you are a human with feedback, feel free to ping me on 
Slack!

I created these scripts with CCS goals in mind (such
as performing Content Quality Assessments), and you
are welcome to use them. Bear in mind that they might
need more testing, and they are based on the structure
of the openshift-docs repo.

## implode-assembly.sh

**implode-assembly.sh** prepares documentation for use
with AI such as NotebookLM by "inlining" the contents
of included modules/snippets while retaining the
assembly context. This way, the AI can also analyze
the markup/raw files in addition to the content.

_usage_

First, make the script executable:

```
$ chmod +x ./implode-assembly.sh
```

Run the script, passing one or more arguments:

```
$ ./implode-assembly.sh <path/to/assembly> 

# or, to implode all assemblies in a directory:

$ ./implode-assembly.sh <path/to/directory>
```

The output is saved to a file in a directory called
`imploded_assemblies`. If the directory does not exist,
it is created. If you passed a directory as an argument,
all relevant directories are created in `imploded_assemblies`.

The imploded assembly document has a default filename
pattern of `<assembly>_<branch>_v<n>.txt`, where _n_ 
increments if a file already exists.

For example:

```
❯ ~/implode-assembly.sh virt/install/installing-virt.adoc
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Output file:    /Users/panousley/imploded_assemblies/installing-virt_main_v2.txt
 Source:         virt/install/installing-virt.adoc
 Timestamp:      2025-06-17 13:19:35
 Git branch:     main
 Modules:        3
   • modules/virt-installing-virt-operator.adoc
   • modules/virt-subscribing-cli.adoc
   • modules/virt-deploying-operator-cli.adoc
 Snippets:       0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

To suppress this output and only print a list of generated
files, run the command with the `-q` or `--quiet` flag.

For example:

```
❯ ~/implode-assembly.sh virt/install -q
Generated files:
/Users/panousley/imploded_assemblies/virt/install/installing-virt_main_v8.txt
/Users/panousley/imploded_assemblies/virt/install/uninstalling-virt_main_v8.txt
/Users/panousley/imploded_assemblies/virt/install/preparing-cluster-for-virt_main_v8.txt
```
