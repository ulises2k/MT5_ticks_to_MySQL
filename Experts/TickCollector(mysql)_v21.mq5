//+------------------------------------------------------------------+
//|                                      TickCollector(mysql)_v1.mq5 |
//+------------------------------------------------------------------+
#property copyright "avoitenko"
#property link      "https://login.mql5.com/ru/users/avoitenko"
#property version   "1.00"

#define CHARTEVENT_INIT    0x0 // Initialization event
#define CHARTEVENT_TICK    0x1 // New tick event
#define SEP                ";"
#define DEBUG_PRINT        false
#define TIMEFRAME          PERIOD_D1

#define IND_FILE "\\Indicators\\TickCollector.ex5"
#resource IND_FILE

#include <libmysql.mqh>
#include <Arrays\ArrayString.mqh>
#include <Arrays\List.mqh>
//--- how to give access rights for a specific IP
// http://qaru.site/questions/45725/error-1130-hy000-host-is-not-allowed-to-connect-to-this-mysql-server

//+------------------------------------------------------------------+
/*
   CREATE DATABASE IF NOT EXISTS `my_db` CHARACTER SET utf8 COLLATE utf8_general_ci

   CREATE TABLE `EURUSD`(
   `time` DATETIME,
   `time_msc` BIGINT DEFAULT 0,
   `bid` DOUBLE,
   `ask` DOUBLE,
   `last` DOUBLE DEFAULT 0,
   `flags` INT DEFAULT 0,
   `volume` BIGINT DEFAULT 0,
   `volume_d1` BIGINT DEFAULT 0);

   INSERT INTO `EURUSD`(`time`, `bid`, `ask`, `last`, `volume`, `time_msc`, `flags`)
   VALUES ('2018-01-01', 1.2, 2.3, 2.4, 5, 6 , 7),('2018-01-01', 1.2, 2.3, 2.4, 5, 6 , 7);
*/

//+------------------------------------------------------------------+
enum ENUM_RUN_MODE {
   RUN_OPTIMIZATION,
   RUN_VISUAL,
   RUN_TESTER,
   RUN_LIVE
};
//+------------------------------------------------------------------+
ENUM_RUN_MODE GetRunMode(void) {
   if(MQLInfoInteger(MQL_OPTIMIZATION))
      return(RUN_OPTIMIZATION);
   if(MQLInfoInteger(MQL_VISUAL_MODE))
      return(RUN_VISUAL);
   if(MQLInfoInteger(MQL_TESTER))
      return(RUN_TESTER);
   return(RUN_LIVE);
}
const ENUM_RUN_MODE run_mode=GetRunMode();

//+------------------------------------------------------------------+
input string  InpDBHost="localhost";//IP address
input uint    InpDBPort=3306;//Port
input string  InpDBName="store_ticks";//Database name
input string  InpDBLogin="root";//Login
input string  InpDBPassword="";//Password
input string  InpSymbolsList="EURUSD;GBPUSD;USDCAD;CADJPY";//Tool List
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct MqlTickEx {
   datetime          time;
   long              time_msc;
   double            bid;
   double            ask;
   double            last;
   uint              flags;
   ulong             volume;
   ulong             volume_d1;
   int               digits;
};
//+------------------------------------------------------------------+
//--- класс для хранения тиков
class CTickData {
private:
   int               m_total;
   MqlTickEx         m_ticks[];
   datetime          m_last_time;//local time
   ulong             m_first_delay;//time of the first tick to measure the total delay
public:
   //+------------------------------------------------------------------+
   void              SetFirstDelay(ulong value) {
      m_first_delay=value;
   }
   ulong             GetFirstDelay() {
      return m_first_delay;
   }
   //+------------------------------------------------------------------+
                     CTickData() {
      m_last_time=TimeLocal();
      Clear();
   }
   //+------------------------------------------------------------------+
   void              Add(MqlTickEx &tick) {
      ArrayResize(m_ticks,m_total+1,1000);
      m_ticks[m_total]=tick;
      m_total++;
   }
   //+------------------------------------------------------------------+
   void              Clear() {
      m_total=0;
      m_first_delay=0;
      ArrayResize(m_ticks,0);
   }
   //+------------------------------------------------------------------+
   bool              At(const int index,MqlTickEx &tick) {
      if(index>=0 && index<m_total) {
         tick=m_ticks[index];
         return true;
      }
      //ZeroMemory(tick);
      return false;
   }
   //+------------------------------------------------------------------+
   int               Total() {
      return m_total;
   }

   //+------------------------------------------------------------------+
   datetime          GetLastTime() {
      return m_last_time;
   }

   //+------------------------------------------------------------------+
   void              SetLastTime(const datetime dt) {
      m_last_time=dt;
   }

};
//+------------------------------------------------------------------+
//--- class for working with the tool
class CMyData : public CObject {
public:
   string            symbol;
   int               digits;
   int               handle;
   CTickData         ticks;
   //+------------------------------------------------------------------+
                    ~CMyData() {
      if(handle!=INVALID_HANDLE) {
         IndicatorRelease(handle);
         if(DEBUG_PRINT)
            Print("Freeing the indicator handle for ",symbol,".");
      }
   }
   //+------------------------------------------------------------------+
   static string     TimeToMySQLStr(const datetime _dt) {
      MqlDateTime mql_dt;
      TimeToStruct(_dt,mql_dt);
      return StringFormat("%04d-%02d-%02d %02d-%02d-%02d",mql_dt.year,mql_dt.mon,mql_dt.day,mql_dt.hour,mql_dt.min,mql_dt.sec);
   }
   //+------------------------------------------------------------------+
   static string     GetCreateString(const string table_name) {
      return "CREATE TABLE `"+table_name+"`("
             +"`time` DATETIME,"
             +"`time_msc` BIGINT DEFAULT 0,"
             +"`bid` DOUBLE,"
             +"`ask` DOUBLE,"
             +"`last` DOUBLE DEFAULT 0,"
             +"`flags` INT DEFAULT 0,"
             +"`volume` BIGINT DEFAULT 0,"
             +"`volume_d1` BIGINT DEFAULT 0);";
   }
   //+------------------------------------------------------------------+
   string            GetInsertString(const string table_name) {
      string result="INSERT INTO `"+table_name+"`(`time`, `time_msc`, `bid`, `ask`, `last`, `flags`, `volume`, `volume_d1`) VALUES";
      //---
      int total=ticks.Total();
      for(int i=0; i<total; i++) {
         MqlTickEx tick;
         if(!ticks.At(i,tick)) {
            Print("Tick reading error ",i);
            continue;
         }

         //---
         if(i>0)
            result+=",";

         //---
         result+="('"+TimeToMySQLStr(tick.time)+"',"
                 +(string)tick.time_msc+","
                 +DoubleToString(tick.bid,digits)+","
                 +DoubleToString(tick.ask,digits)+","
                 +DoubleToString(tick.last,digits)+","
                 +(string)tick.flags+","
                 +(string)tick.volume+","
                 +(string)tick.volume_d1+")";
      }
      return result;
   }

   //+------------------------------------------------------------------+
   static string     GetInsertString(const string table_name,MqlTickEx &tick) {
      string result="INSERT INTO `"+table_name+
                    "`(`time`, `time_msc`, `bid`, `ask`, `last`, `flags`, `volume`, `volume_d1`) VALUES"+
                    " ('"+TimeToMySQLStr(tick.time)+"',"
                    +(string)tick.time_msc+","
                    +DoubleToString(tick.bid,tick.digits)+","
                    +DoubleToString(tick.ask,tick.digits)+","
                    +DoubleToString(tick.last,tick.digits)+","
                    +(string)tick.flags+","
                    +(string)tick.volume+","
                    +(string)tick.volume_d1+")";

      return result;
   }

};

//---
CList list;
datetime wm_time_current=0;
int wm_symbols_total=0;
CMySQL_Connection mysql;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {

   CArrayString symbols;
   if(run_mode==RUN_LIVE) {
      if(_UninitReason==REASON_PROGRAM ||    //start of the program
            _UninitReason==REASON_PARAMETERS) { //change of parameters

         if(InpSymbolsList=="") {
            //--- all instruments from Market Watch
            int total=SymbolsTotal(true);
            for(int i=0; i<total; i++) {
               string _symbol=SymbolName(i,true);
               if(!SymbolInfoInteger(_symbol,SYMBOL_CUSTOM) && symbols.SearchLinear(_symbol)==-1)
                  symbols.Add(_symbol);
            }

            if(symbols.Total()==0)
               Print("The tool list is empty.");

         } else {
            //--- parsing tool string

            string symb_list=InpSymbolsList;
            StringReplace(symb_list,";"," ");
            StringReplace(symb_list,","," ");
            while(StringReplace(symb_list,"  "," ")>0);
            //---
            string result[];
            int total=StringSplit(symb_list,' ',result);
            for(int i=0; i<total; i++) {
               //--- проверка на пустую строку
               if(StringLen(result[i])==0)
                  continue;
               //---
               if(SymbolSelect(result[i],true)) {
                  if(symbols.SearchLinear(result[i])==-1)
                     symbols.Add(result[i]);
               } else {
                  Print("Tool '",result[i],"' not found.");
               }
            }
            //---
            if(symbols.Total()==0)
               Print("The tool list is empty.");
         }
      }
   } else {
      //--- в тестере добавляем только текущий инструмент
      symbols.Add(_Symbol);
   }

//--- добавление инструментов
   int total=symbols.Total();
   for(int i=0; i<total; i++) {
      string _symbol=symbols.At(i);

      //--- проверка, есть ли инструмент в списке
      bool found=false;
      int _total= list.Total();
      for(int k=0; k<_total; k++) {
         CMyData *item=list.GetNodeAtIndex(k);
         if(item.symbol==_symbol) {
            found=true;
            break;
         }
      }

      //--- добавление, если нет в списке
      if(!found) {
         if(DEBUG_PRINT)
            Print("Adding ",_symbol," to the list of instruments.");
         //---
         list.Add(new CMyData);
         CMyData *item=list.GetCurrentNode();
         item.symbol=_symbol;
         item.digits=(int)SymbolInfoInteger(_symbol,SYMBOL_DIGITS);
         item.handle=iCustom(item.symbol,TIMEFRAME,GetResourceName(IND_FILE),ChartID(),0);
         if(item.handle==INVALID_HANDLE) {
            Print("Incorrect indicator handle for ",_symbol);
            return(INIT_FAILED);
         }
      }
   }

//--- удаление лишних инструментов (остались от предыдущих запусков/настроек)
   total=list.Total();
   for(int i=total-1; i>=0; i--) {
      CMyData *item=list.GetNodeAtIndex(i);
      if(symbols.SearchLinear(item.symbol)==-1) {
         //--- убрать из обзора рынка
         SymbolSelect(item.symbol,false);
         if(DEBUG_PRINT)
            Print("Deleting ",item.symbol," from the list of instruments.");
         list.Delete(i);
      }
   }

//---
   EventSetTimer(1);
   OnTimer();

//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(reason==REASON_PROGRAM     ||
         reason==REASON_RECOMPILE   ||
         reason==REASON_REMOVE      ||
         reason==REASON_PARAMETERS  ||
         reason==REASON_INITFAILED) {
      //--- close connection when changing parameters
      mysql.Close();

      //--- reset the time of the last call
      mysql.Tag(0);

      //--- remove indicator handles
      int total=list.Total();
      for(int i=total-1; i>=0; i--) {
         CMyData *item=list.GetNodeAtIndex(i);
         IndicatorRelease(item.handle);
      }

      //---
      list.Clear();
   }

   EventKillTimer();
}
//+------------------------------------------------------------------+
void OnTick() {

   if(run_mode==RUN_VISUAL ||
         run_mode==RUN_TESTER) {
      //--- запись тиков в тестере
      MqlTick tick;
      SymbolInfoTick(_Symbol,tick);

      //---
      long tick_volume[1]= {0};
      CopyTickVolume(_Symbol,TIMEFRAME,0,1,tick_volume);

      //---
      long lparam=CHARTEVENT_TICK;
      double dparam=tick.bid;
      string sparam=_Symbol+SEP
                    +(string)tick.time+SEP
                    +(string)tick.time_msc+SEP
                    +DoubleToString(tick.bid,_Digits)+SEP
                    +DoubleToString(tick.ask,_Digits)+SEP
                    +DoubleToString(tick.last,_Digits)+SEP
                    +(string)tick.flags+SEP
                    +(string)tick.volume+SEP
                    +(string)tick_volume[0]+SEP
                    +(string)_Digits+SEP
                    +(string)GetMicrosecondCount();

      //--- отправить тик
      OnChartEvent(CHARTEVENT_CUSTOM,lparam,dparam,sparam);
   }

}
//+------------------------------------------------------------------+
void OnTimer() {

//--- поддержание соединения
   if(run_mode==RUN_LIVE) {
      if(TimeCurrent()-mysql.Tag()>2) {
         mysql.Tag(TimeCurrent());

         int count=3;
         while(count-->0) {
            //---
            ENUM_MYSQL_STATUS status=mysql.GetStatus();

            if(DEBUG_PRINT)
               Print(EnumToString(status));

            switch(status) {
            case STATUS_OK:
               count=0;
               break;

            //---
            case STATUS_NOT_INIT:
               mysql.Init();
               break;

            //---
            case STATUS_NOT_CONNECTED:
               if(!mysql.Connect(InpDBHost,InpDBPort,InpDBName,InpDBLogin,InpDBPassword,"",0)) {
                  Print("Error #",mysql.GetLastError(),"-",mysql.GetErrorDescription());
                  count=0;
               } else {
                  Print("Connection established c ",mysql.GetHostInfo());
                  Print("Server: ",mysql.GetServerInfo());
               }
               break;
            }
         }
      }
   }

//--- обновление инструментов в обзоре рынка
//--- необходимо для работы индикаторов
   if(run_mode==RUN_LIVE) {
      if(wm_time_current!=TimeCurrent() && wm_symbols_total!=SymbolsTotal(true)) {
         wm_time_current=TimeCurrent();
         wm_symbols_total=SymbolsTotal(true);
         //---
         int total=list.Total();
         for(int i=0; i<total; i++) {
            CMyData *item=list.GetNodeAtIndex(i);
            SymbolSelect(item.symbol,true);
         }
      }
   }
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
   ulong gmc=GetMicrosecondCount();

   if(id==CHARTEVENT_CUSTOM) {
      if(lparam==CHARTEVENT_INIT) {
         //Print("Init ",sparam);
      }

      //---
      if(lparam==CHARTEVENT_TICK) {
         //Print("Tick ",sparam);

         //--- парсинг строки тика
         MqlTickEx tick= {};
         string result[];
         int total=StringSplit(sparam,';',result);
         if(total>10) {
            //Symbol,(long)DateTime,(long)DateTime_msec,Bid,Ask,Last,(int)Flags,(int)Volume
            //--- symbol
            string _symbol=result[0];

            //--- (long)DateTime
            tick.time=StringToTime(result[1]);
            //---(long)DateTime_msec
            tick.time_msc=StringToInteger(result[2]);

            tick.bid=StringToDouble(result[3]);
            tick.ask=StringToDouble(result[4]);
            tick.last=StringToDouble(result[5]);

            tick.flags=(int)StringToInteger(result[6]);
            tick.volume=StringToInteger(result[7]);

            tick.volume_d1=StringToInteger(result[8]);

            tick.digits=(int)StringToInteger(result[9]);
            //ulong local_delay=StringToInteger(result[10]);

            //string str=_symbol+SEP+(string)tick.time+SEP+(string)tick.time_msc+SEP+DoubleToString(tick.bid,_digits)+SEP+DoubleToString(tick.ask,_digits)+SEP+
            //           DoubleToString(tick.last,_digits)+SEP+(string)tick.flags+SEP+(string)tick.volume+SEP+(string)tick.volume_d1;
            //Print("tick: ",str);

            string sql=CMyData::GetInsertString(_symbol,tick);

            //---
            int count=4;
            while(count-->0) {
               ENUM_MYSQL_STATUS status=mysql.ExecSQL(sql);
               switch(status) {
               //---
               case STATUS_OK:
                  Print("Recorded 1 tick ",_symbol," ",DoubleToString((GetMicrosecondCount()-gmc/*item.ticks.GetFirstDelay()*/)/1000.0,3)," msec.");
                  count=0;
                  //item.ticks.Clear();
                  break;

               //---
               case STATUS_BAD_REQUEST:

                  //--- таблицы не существует
                  if(mysql.GetLastError()==1146) {
                     //--- создаем таблицу
                     string sql2=CMyData::GetCreateString(_symbol);
                     ENUM_MYSQL_STATUS status2=mysql.ExecSQL(sql2);
                     if(status2==STATUS_OK)
                        Print("Created table for ",_symbol);
                     else
                        Print("Error creating table for ",_symbol,": #",mysql.GetLastError(),"-",mysql.GetErrorDescription());
                  } else {
                     count=0;
                     Print("BAD_REQUEST ",mysql.GetLastError()," ",mysql.GetErrorDescription());
                  }
                  break;

               //---
               case STATUS_NOT_CONNECTED:
                  //Print("NOT_CONNECTED");
                  if(!mysql.Connect(InpDBHost,InpDBPort,InpDBName,InpDBLogin,InpDBPassword,"",0)) {
                     switch(mysql.GetLastError()) {
                     case 2058: //reconnect
                        mysql.Close();
                        break;
                     default:
                        return;
                        break;
                     }
                     Print("Error #",mysql.GetLastError(),"-",mysql.GetErrorDescription());
                  }
                  break;

               //---
               case STATUS_NOT_INIT:
                  mysql.Init();
                  break;
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
string GetResourceName(string path) {
   if(StringGetCharacter(path,0)=='\\')
      path="::"+StringSubstr(path,1);
   return(path);
}
//+------------------------------------------------------------------+
