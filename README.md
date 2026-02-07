# Dkinplot

![A 1 year plot](example.png)

### Usage

#### CSV Log format

```csv
timestamp,user,med,amount,ROA,comment
2025-12-03T08:00:31.987Z,0xea,Metaphedrone,50mg,Intravenous,left-median-cubital hydrochloride-salt
2025-12-03T08:13:22.857Z,0xea,Metaphedrone,90mg,Intravenous,left-median-cubital hydrochloride-salt
```

```shell
ruby dkinplot.rb -l example.csv -o plot.png -s "2024-01-01T00:00" -t "2024-06-01T00:00" -r "1366x755"
```

#### Journal logs

```shell
ruby dkinplot.rb -j example.csv -o plot.png -s "2024-01-01T00:00" -t "2024-06-01T00:00" -r "1366x755"
ruby 
```
