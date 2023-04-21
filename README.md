Command-line utility. Reads text from file(s) or stdin, then filters that and counts matches. Supports:

- all major Unicode formats;
- multiple glob patterns for files;
- input file paths listed in stdin;
- plain and regular expression patterns;
- logical operations on patterns;
- multi-line search.

USAGE:

```
chest [OPTIONS]

-?,-h[elp]         - this help screen

-q[uiet]           - no output

-v[erbose]         - detailed output

-a[ll]             - scan all files including the hidden ones
                    (when a filename starts with '.')

-c[ount]           - show the number of matched lines or blocks (for the
                    multi-line match) rather than the actual text;
                    will be turned on if -e[xp[ect]] is specified

-d[ir] DIRs        - one or more directories as bases to resolve GLOBs with
                    (relative) sub-directories; see -f[iles]

-e[xp[ect]] RANGE  - expected RANGE for the number of matching lines
                    or blocks (turns -c[ount] on):
                    3   - exactly 3
                    2,5 - between 2 and 5
                    2,  - 2 or more
                    ,5  - up to 5

-m[ulti[[-]line]]  - multi-line search: applies to all patterns and converts
                    plain pattern into a regex, spaces are converted to the
                    'any number of whitespaces' pattern: [\s]+

-n[o[-]content]    - perform filtering on file paths or names
                    rather than those content

-o[ut],-format FMT - output format, the following placeholders accepted:
                    c  - number of matching lines or blocks
                    l  - sequential line number
                    f  - file name
                    p  - file path
                    s  - text (content) of the matched line(s)
                    \t - tab character
                    \n - line-break character

                    in order to use brackets, pipes, tabs or line-breaks, you
                    need to wrap FMT in single or double quotes as follows:
                    'p|m\n' or "p (l)\ts\n";

                    if none of the placeholders specified, FMT will be treated
                    as a field separator in default format)

-p[lain] TEXTs     - filter lines matching or not matching plain one or more
                    text (literal) case-sensitive patterns, has sub-options:
                    -i[case] - ignore case (case-insensitive on)
                    +i[case] - exact (case-insensitive off)
                    -and     - match prev pattern AND this one
                    -not     - next pattern should NOT be found
                    -or      - match prev patterns OR this one
                    -r[egex] - switch to -regex    

-r[egex] REGEXes   - similar to -plain, but using regular expression patterns
                    rather than plain text strings, has a sub-option -p[lain]
                    to switch back to plain text (literal)

-f[ile[s]] GLOBs   - one or more glob patterns as separate arguments,
                    case-insensitive for Windows, and case-sensitive
                    for POSIX-compliant file systems (Linux, macOS)

-x[args]           - similar to -f[iles], but takes glob patterns from stdin
                    (one per line) rather than from the command-line arguments;
                    in this case, -f[iles] ignored

Option names are case-insensitive and dash-insensitive: you can use
any number of dashes in the front, in the middle or at the back of
any option name.

EXAMPLES:

chest -dir "${HOME}/Documents" -files '**' "../*.csv" -plain -not ","
chest -d "${HOME}/Projects/chest/app" -files '**.{gz,zip}' -e 3 -o "c:p"
```