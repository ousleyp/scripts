# scripts

I can't fully vouch for the quality of these scripts,
which were generated with AI chatbot assistance.

I created these scripts with CCS goals in mind (such
as performing Content Quality Assessments), and you
are welcome to use them. Bear in mind that they might
be incomplete.

## implode-assembly.sh

**implode-assembly.sh** prepares documentation for use
with AI such as NotebookLM by "inlining" the contents
of included modules/snippets while retaining the
assembly context. This way, the AI can also analyze
the markup/raw files in addition to the content.

_usage_

```
$ chmod +x ./implode-assembly.sh # make it executable

$ ./implode-assembly.sh <path/to/assembly> <path/to/another/assembly>
```

The output is saved to a file in a directory called
`imploded_assemblies`. If the directory does not exist,
it is created.

The imploded assembly document has a default filename
pattern of `<assembly>_<branch>_v<n>.adoc`, where _n_ 
increments if a file already exists.

For example:

```
❯ ~/implode-assembly.sh virt/install/installing-virt.adoc
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Imploded:       /Users/panousley/imploded_assemblies/installing-virt_main_v2.adoc
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

If you prefer zsh as your shell, `implode-assembly.zsh` works the same way.

### roadmap

- add directory support 
