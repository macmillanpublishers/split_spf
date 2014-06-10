# Split and Rename SPF files

## Dependencies

Ruby must be installed on the system running the script. The system must also support the basic bash commands `cp` and `rm`.

Splitting the file depends on the following:

* Each file starts with the landscape layout binary code: ESC&l1O followed by a line break followed by an initial FF binary pagebreak
* Page breaks are demarked by the binary FF character
* The first page of every unique statement contains the string "Page 1" somewhere on that page

Renaming depends on 4 spans of data within each statement being formatted as follows:

_Author Number:_

* String: "AUTHOR:""
* Followed by: At least one up to any number of consecutive spaces
* Followed by: At least one up to any number of consecutive digits

_Payee Number:_

* String: "PAYEE:""
* Followed by: At least one up to any number of consecutive spaces
* Followed by: At least one up to any number of consecutive digits

_ISBN_

* String: "978"
* Followed by: 10 digits

_Date_

* String: "ROYALTY STATEMENT FOR PERIOD ENDING "
* Followed by: 2 digits + / + 4 digits

## Distribution End Points

TK

## Deployment

TK

## Stakeholders

Ray Lockwood
Ed Lewandowski
Bill Barry
Fritz Foy

## Usage

On the command line, run:

```
$ ruby splitspf.rb inputfilename.spf
```