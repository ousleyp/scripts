# scripts

I can't fully vouch for the quality of these scripts,
which were generated with AI chatbot assistance.

I created these scripts with CCS goals in mind (such
as performing Content Quality Assessments), and you
are welcome to use them. Bear in mind that they might
be incomplete.

## implode-assembly.zsh

**implode-assembly.zsh** prepares documentation for use
with AI such as NotebookLM by "inlining" the contents
of included modules/snippets while retaining the
assembly context. This way, the AI can also analyze
the markup/raw files in addition to the content.

_usage_

```
$ chmod +x ./implode-assembly.zsh # make it executable

$ ./implode-assembly.zsh <path/to/assembly>
```

The output is saved to a file in a directory called
`imploded_assemblies`. If the directory does not exist,
it is created.

The imploded assembly document has a default filename
pattern of <assembly>_<branch>-<n>.adoc, where _n_ 
increments if a file already exists.

### roadmap

- bash shell compatibility
- add directory support 
