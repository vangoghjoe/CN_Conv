one liner to convert to GB
$o = get-content $file-of-sizes
rm .\new-sizes.txt ; foreach ($l in $o) { $l = $l -replace "\s*"; if ($l -eq "") {$l = "0"}; if (-not ($l -match "\D")) { $l += "mb"} ; write ((0 + $l)/1gb)  >> new-sizes.txt }


9.25MB
59.2MB
161MB
127MB
156MB
854MB
1.91GB
0.99GB
2.05MB
1.30MB
329MB
532KB
320KB
753 MB
924 KB
182 MB
10.5MB
3.08MB
437 MB
0.98 GB
236 MB
720 MB
35.7 MB
214 MB
86.1 MB
46.6 MB
1.76 GB
38.4 MB
4.53 GB
881 MB
76.4 MB
510MB
3.25MB
556MB
14.0MB
7.38MB
605MB
1.08 GB
50 MB
1 GB
14.3 MB
64.6
262MB
127 MB
169 MB
11.0 MB
8.17 MB
2.04 GB
64.6 MB
9.24 MB
10.6 MB
594 MB
4.31GB
1.18MB
73.9MB
291MB
5.55MB
774MB
163MB
408MB
1.47GB
1.50GB
7.38MB
1.31GB
34.6MB
171 MB
707 MB
9.43 MB
235MB
1.30MB
344MB
14.4MB
29.7MB
6.31MB
4.20MB
696 MB
13.6 MB
8.41 GB
15.5 MB
11.7 MB
814 MB
3.70 MB
127 MB
61.1 MB
16.5 MB
3.59 MB
54.9 MB
43 mb
267 MB
4.06

2.27 GB
293 MB
154 MB
7.03 MB
12.0 MB
261 MB
6.65 MB
17.1 MB
133 mb
681 mb
568 MB
582 MB
232 MB
335 MB
100MB
5.87MB
144KB
188KB
444 MB
41.0 MB
13.8 MB
152 KB
1.26MB
16.6 MB
4.18MB
24.7MB
409MB
138 MB
743 mb
203MB
2.92 GB
401 MB
2.45 GB
233 MB
103 MB
40.9 MB
3.22MB
26.2MB
15.6MB
106MB
11.5MB











327 MB
346 MB




3.37MB




















































































































































































































































117 MB





25.1 MB
1.89 GB
17.4 MB




































38.3 MB
96.1 MB
197 MB
128 MB

































3.46MB
3.7MB










21.3 MB
27.3 MB
30.6 MB
37.6 MB
13.1 MB
21.3 MB
441 MB



















































































































































































971 MB
1.01 GB
296 MB
879 mb
1.83 gb
12.8 mb






















