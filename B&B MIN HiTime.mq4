//+-------------------------------------------------------------------------------+
//|                                                     BULL&BEAR MIN EA 1.5 mq4  |
//|                                                Copyright REALCHARLEX ALGTECH  |
//|                                                   www.realcharlexalgtech.com  |
//+-------------------------------------------------------------------------------+
#property     strict
#include      <stdlib.mqh>
#property     copyright           "Copyright © 2024, REALCH@RLEX ALGTECH"
#property     version             "1.1"
#property     description         "Trading does not have to make you suffer losses or stress, trading should be synonymous with tranquility and high quality of life."

enum enum_day
  {
   sunday      = 0,
   monday      = 1,
   tuesday     = 2,
   wednesday   = 3,
   thursday    = 4,
   friday      = 5,
   saturday    = 6
  };
input bool     showPanel                    = false;        // Show panel
input string   startTime                    = "00:10";
input string   endTime                      = "23:50";
input string   highStartTime                = "09:00";
input string   highEndTime                  = "18:00";
input enum_day startDay                     = 0;
input enum_day endDay                       = 6;

input ENUM_TIMEFRAMES volatilityPeriod      = PERIOD_M15;   // Volatility period
input ENUM_TIMEFRAMES recoveryPeriod_low    = PERIOD_M5;    // Recovery Period low
input ENUM_TIMEFRAMES recoveryPeriod_high   = PERIOD_M15;   // Recovery Period High

input int      overlap_Pips                 = 1;            // Overlap pips
input double   mainTakeProfit               = 1;            // MAIN PROFIT
input double   maxLotBuy                    = 1;            // max lot BUY
input double   maxLotSell                   = 1;            // max lot SELL

input bool     buy_restart                  = true;         // Restart BUY
input bool     sell_restart                 = true;         // Restart SELL
input double   buy_firstLot                 = 0.01;         //  - - - - - - - - - - - BUY first LOT low   
input double   sell_firstLot                = 0.01;         //  - - - - - - - - - - - SELL first LOT low    
input double   buy_profitOrder1             = 0.2;
input double   sell_profitOrder1            = 0.2;
input int      BUY_distance                 = 5;
input int      SELL_distance                = 5;
input int      BUY_distance_High           = 10;
input int      SELL_distance_High     = 10;
input double   priceToStopBuys              = 0;
input double   priceToStopSells             = 0;

input double   maxSpread                    = 2.0;          // Max spread
input double   Risk                         = 100;          // Risk %

// Global variables to track button click states
bool          close_buy_clicked, close_sel_clicked     = false;
datetime      last_click_time_buy, last_click_time_sel = 0;

bool          upTrend, downTrend, stopBuy, stopSell    = false;
double        atrValue, atrMin, atrMax, atrAvg, ATR_Step,  ATR_Level_2, ATR_Level_3, ATR_Level_4,  ATR_Level_5, ATR_Level_6, ATR_Level_7 = 0;
double        buy_first_lot, sell_first_lot, buyFirstOrdersLot, sellFirstOrdersLot = 0.01;

double        ATR_DistanceFactor      = 1,      ATR_LotsFactor         = 1,      ATR_factorOrder1      = 1;
double        firstOrdersLot          = 0.01,   minimumProfitPerOrder  = 0,      minimumOverlapProfit  = 6;
double        buyTakeprofit           = 3,      sellTakeprofit         = 3,      distanceCheck         = 0,     point            = 0,  tickValue  = 0;
int           RSIOversold             = 25,     RSIOverbought          = 75,     StochOversold         = 25,    StochOverbought  = 75;
int           overlapAdd              = 0,      overlapPipsAdded       = 0;
int           slippage                = 3,      BUYS                   = 0,      SELLS                 = 0;
int           magicNo_1               = 9768,   magicNo_2              = 0195,   magicNo_3             = 4503,  magicNo_H1       = 60, magicNo_H4 = 240;
long          chartId                 = 0;
datetime      lastDebugTime           = 0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(showPanel)
      x_CreateButtons();
   point = Point;
   if(_Digits == 3 || _Digits == 5)
      point *= 10;
   chartId = ChartID();
//CalculateATRLevels();
   PrintData();
   if(IsTesting())
      HideTestIndicators(true);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, "Close_Buy_btn");
   ObjectDelete(0, "Close_Sel_btn");
   ObjectDelete("ProfitB");
   ObjectDelete("ProfitS");
   ObjectDelete("Spread");
   ObjectDelete("ChartProfit");
   ObjectDelete("TotalProfit");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(IsTesting())
      HideTestIndicators(true);
   if(showPanel)
      x_ShowTexts();
   atrValue       = iATR(_Symbol, volatilityPeriod, 14, 0);
   BUYS           = CountOrders(OP_BUY);
   SELLS          = CountOrders(OP_SELL);
   if(BUYS > 0)
     {
      CheckAndOpenOrder(OP_BUY, "REAL GAINNER Hedge Buy - - - - -");
      CloseAllOrdersByProfitPositive(OP_BUY, buyTakeprofit);
      CloseAllOrdersByProfitNegative(OP_BUY, Risk);
     }
   if(SELLS > 0)
     {
      CheckAndOpenOrder(OP_SELL, "REAL GAINNER Hedge Sell - - - - -");
      CloseAllOrdersByProfitPositive(OP_SELL, sellTakeprofit);
      CloseAllOrdersByProfitNegative(OP_SELL, Risk);
     }
   if(BUYS > 0 || SELLS > 0)
     {
      CalculateATRLevels();
      FactorATR();
      if(!IsVisualMode() && (!IsTesting()))
         PrintEveryXMinutes();
     }
   if(BUYS > 1)
      Overlap(OP_BUY);
   if(SELLS > 1)
      Overlap(OP_SELL);
   if(!allowOrders())
      return;
   if(buy_restart && BUYS == 0)
      GenerateTradeSignals(OP_BUY);
   if(sell_restart && SELLS == 0)
      GenerateTradeSignals(OP_SELL);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GenerateTradeSignals(int orderType)
  {
   if(orderType == OP_BUY)
     {
      // Actualiza stopBuy usando ternario
      stopBuy = (priceToStopBuys != 0 && Ask >= priceToStopBuys) ? true
                : (priceToStopBuys != 0 && Ask < priceToStopBuys) ? false
                : stopBuy;
      // Verifica si debe abrir una orden de compra
      if((priceToStopBuys == 0 || Ask <= priceToStopBuys) && !stopBuy)
         OpenOrder(OP_BUY, buy_firstLot, 0, 0, "B & B Buy 1 ----", magicNo_1);
     }
   if(orderType == OP_SELL)
     {
      // Actualiza stopSell usando ternario
      stopSell = (priceToStopSells != 0 && Bid <= priceToStopSells) ? true
                 : (priceToStopSells != 0 && Bid > priceToStopSells) ? false
                 : stopSell;
      // Verifica si debe abrir una orden de venta
      if((priceToStopSells == 0 || Bid >= priceToStopSells) && !stopSell)
         OpenOrder(OP_SELL, sell_firstLot, 0, 0, "B & B Sell 1 ----", magicNo_1);
     }
// Mantén los valores de los lotes iniciales
   //buyFirstOrdersLot  = buy_firstLot;
   //sellFirstOrdersLot = sell_firstLot;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAndOpenOrder(int orderType, string orderLabel)
  {
   double currentSpread  = MarketInfo(Symbol(), MODE_SPREAD) * point;
   if(currentSpread > maxSpread)
      return;

// Obtener la hora actual en formato HH:MM
   datetime currentTime       = TimeLocal();
   string   currentHourMinute = TimeToString(currentTime, TIME_MINUTES);

// Determinar si estamos en el horario especial
   bool isHighTime = (currentHourMinute >= highStartTime && currentHourMinute <= highEndTime);

// Seleccionar la distancia de órdenes en función del horario
   int buyDistance    = isHighTime ? BUY_distance_High  : BUY_distance;
   int sellDistance   = isHighTime ? SELL_distance_High : SELL_distance;
   int recoveryPeriod = isHighTime ? recoveryPeriod_low : recoveryPeriod_high;

   double   rsiRecov            = iRSI(_Symbol, recoveryPeriod, 6, PRICE_CLOSE, 0);
   double   preRsiRecov         = iRSI(_Symbol, recoveryPeriod, 6, PRICE_CLOSE, 1);
   bool     RsiRecov_buy_20     = preRsiRecov <= 20 && rsiRecov > 20;
   bool     RsiRecov_buy_30     = preRsiRecov <= 30 && rsiRecov > 30;
   bool     RsiRecov_buy_50     = preRsiRecov <= 50 && rsiRecov > 50;
   bool     RsiRecov_sell_70    = preRsiRecov >= 70 && rsiRecov < 70;
   bool     RsiRecov_sell_80    = preRsiRecov >= 80 && rsiRecov < 80;
   bool     RsiRecov_sell_50    = preRsiRecov >= 50 && rsiRecov < 50;

   int      lastOrder           = -1;
   double   lastOpenPrice       = 0;
   double   lastOrderLot        = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol && OrderType() == orderType)
        {
         lastOrder     = i;
         lastOpenPrice = OrderOpenPrice();
         lastOrderLot  = OrderLots();
         break;
        }
     }

// Determinar la distancia a utilizar
   distanceCheck = (orderType == OP_BUY ? buyDistance : sellDistance) * ATR_DistanceFactor * point;
   distanceCheck *= ((orderType == OP_BUY && downTrend) || (orderType == OP_SELL && upTrend)) ? 1.5 : 1.0;

   double currentDistance = (lastOrder >= 0) ? ((orderType == OP_BUY) ? (lastOpenPrice - Ask) : (Bid - lastOpenPrice)) : 0;
//double lotMultiplier   = (currentDistance >= 5 * distanceCheck) ? 4.5 : (currentDistance >= 4 * distanceCheck) ? 3.5 : (currentDistance >= 3 * distanceCheck) ? 2.5 : (currentDistance >= 2 * distanceCheck) ? 1.5 : 1.0;

   if(lastOrder >= 0 && ((orderType == OP_BUY && Ask <= lastOpenPrice - distanceCheck) || (orderType == OP_SELL && Bid >= lastOpenPrice + distanceCheck)))
     {
      double totalOpenLotSize = CheckLotSize(orderType);
      //double basicLotSize     = CalculateLotSize(totalOpenLotSize, (OrderType() == OP_BUY ? buyFirstOrdersLot : sellFirstOrdersLot));
      double basicLotSize     = CalculateLotSize(totalOpenLotSize, (OrderType() == OP_BUY ? buy_firstLot : sell_firstLot));
      basicLotSize            = basicLotSize >= lastOrderLot ? basicLotSize : lastOrderLot;//********/////***ANALIZAR=>QUITAR?***NO permite que el nuevo lot sea menor al anterior, pero si el anterior fue precedido por una gran distancia y el nuevo no?

      double adjusted_ATR_LotsFactor = ATR_LotsFactor > 5 ? 5 : ATR_LotsFactor;
      double factorLotSize           = basicLotSize * (adjusted_ATR_LotsFactor);
      factorLotSize = MathMin(factorLotSize, lastOrderLot * 2); // No puede ser mayor al doble del último lotaje

      if(orderType == OP_BUY)
        {
         factorLotSize = MathMin(factorLotSize, maxLotBuy);
         if(RsiRecov_buy_20 || RsiRecov_buy_30)
           {
            OpenOrder(orderType, factorLotSize, 0, 0,  "B & B RECOVERY BUY ----", 0);
            Print(__LINE__, " Recovery Buy order");
            PrintData();
           }
        }
      else
         if(orderType == OP_SELL)
           {
            factorLotSize = MathMin(factorLotSize, maxLotSell);
            if(RsiRecov_sell_80 || RsiRecov_sell_70)
              {
               OpenOrder(orderType, factorLotSize, 0, 0,  "B & B RECOVERY SELL ----", 0);
               Print(__LINE__, " Recovery Sell order");
               PrintData();
              }
           }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenOrder(int Type, double Lotz, double SL, double TP, string comment, int magic_No)
  {
   int err;
   color  l_color = Red;
   double l_price = 0;
   double l_TP    = 0;
   double l_SL    = 0;
   RefreshRates();
// Price and color for the trade type
   if(Type == OP_BUY)
     {
      l_price = Ask;
      l_color = Blue;
      l_TP    = (TP > 0) ? l_price + TP * point : 0;
      l_SL    = (SL > 0) ? l_price - SL * point : 0;
     }
   if(Type == OP_SELL)
     {
      l_price = Bid;
      l_color = Red;
      l_TP    = (TP > 0) ? l_price - TP * point : 0;
      l_SL    = (SL > 0) ? l_price + SL * point : 0;
     }
// Avoid collusions
   while(IsTradeContextBusy())
      Sleep(1000);
   long l_datetime = TimeCurrent();
   l_price         = normPrice(l_price);
   Lotz            = normalizeLots(Lotz);
   if(!CheckMoneyForTrade(_Symbol, Lotz, Type))
      return;
   int l_ticket = OrderSend(_Symbol, Type, Lotz, l_price, 10, l_SL, l_TP, comment, magic_No, 0, l_color);
// Retry if failure
   if(l_ticket == -1)
     {
      while(l_ticket == -1 && TimeCurrent() - l_datetime < 60 && !IsTesting())
        {
         err   = GetLastError();
         if(err == 148)          // Invalid Trade Volume
            return;
         Sleep(1000);
         while(IsTradeContextBusy())
            Sleep(1000);
         RefreshRates();
         if(Type == OP_BUY)
            l_price = Ask;
         if(Type == OP_SELL)
            l_price = Bid;
         l_ticket   = OrderSend(_Symbol, Type, Lotz, l_price, 10, 0, l_TP, comment, magic_No, 0, l_color);
        }
      if(l_ticket == -1)
         Print(__FUNCTION__, " ", __LINE__, " (OrderSend Error) " + ErrorDescription(GetLastError()));
     }
  }
//+------------------------------------------------------------------+
//| Count orders                                                     |
//+------------------------------------------------------------------+
int CountOrders(int Type)
  {
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol)
         if(OrderType() == Type)
            count++;
     }
   return (count);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//double CheckLotSize(int orderType)
//  {
//   double totalLotSize = 0;
//   int maxRetries = 10;    // Maximum number of retries
//   int retryDelay = 500;   // Delay between retries in milliseconds
//
//   for(int attempt = 0; attempt < maxRetries; attempt++)
//     {
//      totalLotSize = 0; // Reset accumulator on each attempt
//
//      RefreshRates(); // Synchronize trade context before iterating orders
//
//      for(int i = 0; i < OrdersTotal(); i++)
//        {
//         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) // Ensure successful selection
//           {
//            if(OrderSymbol() == _Symbol && OrderType() == orderType) // Match symbol and type
//               totalLotSize += OrderLots(); // Accumulate lot sizes
//           }
//         else
//           {
//            Print("CheckLotSize: Failed to select order at index ", i, " - Error: ", GetLastError());
//           }
//        }
//
//      totalLotSize = NormalizeDouble(totalLotSize, 2);
//
//      if(totalLotSize > 0) // If valid lot size found, break out of retry loop
//         break;
//
//      Sleep(retryDelay); // Wait before retrying
//     }
//
//   if(totalLotSize == 0) // After retries, if still 0, log an error
//      Print("CheckLotSize: Maximum retries reached. Lot size is 0. Possible issue in orders or conditions.");
//
//   return totalLotSize;
//  }

//double CheckLotSize(int orderType)
//  {
//   double totalLotSize = 0;
//   int maxRetries = 10;  // Número máximo de reintentos
//   int retryDelay = 500; // Tiempo de espera entre reintentos en milisegundos
//
//   for(int attempt = 0; attempt < maxRetries; attempt++)
//     {
//      totalLotSize = 0; // Reinicia el acumulador en cada intento
//      for(int i = 0; i < OrdersTotal(); i++)
//        {
//         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol && OrderType() == orderType)
//            totalLotSize += OrderLots();
//        }
//      totalLotSize = NormalizeDouble(totalLotSize, 2);
//
//      if(totalLotSize > 0)   // Si encuentra lotaje, rompe el ciclo
//         break;
//
//      Sleep(retryDelay);  // Espera antes de reintentar
//     }
//
//   if(totalLotSize == 0)   // Si tras todos los intentos el lotaje sigue siendo cero
//      Print("CheckLotSize: Máximo número de reintentos alcanzado, lotaje sigue siendo 0.");
//
//   return totalLotSize;
//  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CheckLotSize(int orderType)
  {
   double totalLotSize = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol && OrderType() == orderType)
         totalLotSize += OrderLots();
     }
   return NormalizeDouble(totalLotSize, 2);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FactorATR()
  {
   if(atrValue > ATR_Level_2 && atrValue < ATR_Level_3)
      ATR_DistanceFactor = ATR_LotsFactor = ATR_factorOrder1 = 2;
   else
      if(atrValue >= ATR_Level_3 && atrValue < ATR_Level_4)
        {
         ATR_DistanceFactor    = ATR_LotsFactor = ATR_factorOrder1 = 3;
         overlapAdd            = 5;
         minimumProfitPerOrder = 1;
        }
      else
         if(atrValue >= ATR_Level_4 && atrValue < ATR_Level_5)
           {
            ATR_DistanceFactor = ATR_LotsFactor  = ATR_factorOrder1       = 4;
            ATR_factorOrder1   = minimumProfitPerOrder = 2;
            overlapAdd         = 10;
           }
         else
            if(atrValue >= ATR_Level_5 && atrValue < ATR_Level_6)
              {
               ATR_DistanceFactor = ATR_LotsFactor  = ATR_factorOrder1 = 5;
               ATR_factorOrder1   = minimumProfitPerOrder = 3;
               overlapAdd         = 15;
              }
            else
               if(atrValue >= ATR_Level_6 && atrValue < ATR_Level_7)
                 {
                  ATR_DistanceFactor = ATR_LotsFactor = ATR_factorOrder1 = 6;
                  ATR_factorOrder1   = minimumProfitPerOrder = 4;
                  overlapAdd         = 20;
                 }
               else
                  if(atrValue >= ATR_Level_7)
                    {
                     ATR_DistanceFactor = ATR_LotsFactor = ATR_factorOrder1 = 7;
                     ATR_factorOrder1   = minimumProfitPerOrder = 5;
                     overlapAdd         = 25;
                    }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Definimos la estructura para almacenar datos específicos de cada símbolo
struct SymbolATRData
  {
   string            symbol;
   double            ATRLevelStar;
   double            ATRLevelStep;
  };

// Creamos un array con los datos de los símbolos y sus valores específicos de ATR
SymbolATRData atrDataArray[] =
  {
     {"EURUSD", 0.0004, 0.0004},
     {"AUDUSD", 0.0004, 0.0003},
     {"GBPUSD", 0.0004, 0.0004},
     {"NZDUSD", 0.0004, 0.0003},
     {"USDCHF", 0.0004, 0.0003},
     {"USDCAD", 0.0004, 0.0002},
     {"EURCAD", 0.0004, 0.0003},
     {"EURCHF", 0.0003, 0.0003},
     {"EURGBP", 0.0003, 0.0003},
     {"EURNZD", 0.0004, 0.0004},
     {"AUDCAD", 0.0004, 0.0002},
     {"AUDCHF", 0.0003, 0.00015},
     {"AUDNZD", 0.0004, 0.0002},
     {"CADCHF", 0.0004, 0.0002},
     {"GBPAUD", 0.0006, 0.0003},
     {"GBPCAD", 0.0006, 0.0003},
     {"GBPCHF", 0.0006, 0.0003},
     {"GBPNZD", 0.0008, 0.0003},
     {"NZDCAD", 0.0004, 0.0002},
//{"NZDCHF", 0.0003, 0.0002},
//{"NZDCHF", 0.0003, 0.0001},
     {"AUDJPY", 0.06, 0.04},
     {"CADJPY", 0.06, 0.04},
     {"CHFJPY", 0.06, 0.04},
     {"EURJPY", 0.06, 0.04},
     {"GBPJPY", 0.06, 0.04},
     {"NZDJPY", 0.06, 0.04},
     {"USDJPY", 0.06, 0.04},
     {"XAUUSD", 2, 1},
     {"XAGEUR", 0.05, 0.04},
     {"BTCUSD", 80, 80},
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateATRLevels()
  {
   bool   symbolFound      = false;
   double fileATRLevelStar = 0.0;
   double fileATRLevelStep = 0.0;

// Buscar el símbolo en el array
   for(int i = 0; i < ArraySize(atrDataArray); i++)
     {
      if(atrDataArray[i].symbol == _Symbol)
        {
         fileATRLevelStar = atrDataArray[i].ATRLevelStar;
         fileATRLevelStep = atrDataArray[i].ATRLevelStep;
         symbolFound = true;
         break;
        }
     }
   if(symbolFound)
     {
      ATR_Level_2 = fileATRLevelStar;
      ATR_Level_3 = ATR_Level_2 + fileATRLevelStep;
      ATR_Level_4 = ATR_Level_3 + fileATRLevelStep;
      ATR_Level_5 = ATR_Level_4 + fileATRLevelStep;
      ATR_Level_6 = ATR_Level_5 + fileATRLevelStep;
      ATR_Level_7 = ATR_Level_6 + fileATRLevelStep;
     }
   else
     {
      int ATR_levels_factor = 4;
      int ATR_Candles = 100; // Configurar el número máximo deseado de velas
      atrMin = DBL_MAX;
      atrMax = DBL_MIN;
      atrAvg = 0.0;
      double totalAtr = 0.0;
      double highVolatilityFactor = 1.8;
      int validCandles = 0;

      // Ajustar ATR_Candles según el historial disponible
      ATR_Candles = MathMin(ATR_Candles, Bars - 1); // Asegurar que no exceda el número de barras disponibles

      // Calcular ATR promedio
      for(int i = 0; i < ATR_Candles; i++)
        {
         double tempATR = iATR(_Symbol, volatilityPeriod, 14, i);
         totalAtr += tempATR;
         validCandles++;
        }
      if(validCandles > 0)   // Verificar si se ha obtenido algún valor
         atrAvg = totalAtr / validCandles;
      else
        {
         Print("Error: No se pudieron calcular valores de ATR válidos.");
         return;
        }

      // Calcular atrMin y atrMax excluyendo velas de alta volatilidad
      validCandles = 0;  // Reiniciar contador para valores válidos
      for(int i = 0; i < ATR_Candles; i++)
        {
         double tempATR = iATR(_Symbol, volatilityPeriod, 14, i);
         if(tempATR > atrAvg * highVolatilityFactor)
            continue;
         if(tempATR < atrMin)
            atrMin = tempATR;
         if(tempATR > atrMax)
            atrMax = tempATR;
         validCandles++;
        }

      // Verificar que atrMax y atrMin sean válidos
      if(validCandles > 0 && atrMax > atrMin)
        {
         ATR_Step = (atrMax - atrMin) / ATR_levels_factor;
         ATR_Level_2 = atrMin + ATR_Step;
         ATR_Level_3 = ATR_Level_2 + ATR_Step;
         ATR_Level_4 = ATR_Level_3 + ATR_Step;
         ATR_Level_5 = ATR_Level_4 + ATR_Step;
         ATR_Level_6 = ATR_Level_5 + ATR_Step;
         ATR_Level_7 = ATR_Level_6 + ATR_Step;
        }
     }
  }
//+------------------------------------------------------------------+
//|              Define lot for order                                |
//+------------------------------------------------------------------+
double CalculateLotSize(double totalLotZ, double initialLot)
  {
//initialLot = initialLot > totalLotZ ? totalLotZ : initialLot;
   double lotSize = initialLot;
   if(totalLotZ <= initialLot * 2)
      lotSize = initialLot;
   else
      if(totalLotZ < initialLot * 6 + 0.03)
         lotSize = initialLot;                // lotSize = initialLot + 0.01;  Se retira suma 0.01, menor incremento en lotaje de cobertura
      else
         if(totalLotZ < initialLot * 9 + 0.09)
            lotSize = initialLot + 0.02;
         else
            if(totalLotZ < initialLot * 12 + 0.18)
               lotSize = initialLot + 0.03;
            else
               if(totalLotZ < initialLot * 15 + 0.30)
                  lotSize = initialLot + 0.04;
               else
                  if(totalLotZ < initialLot * 18 + 0.45)
                     lotSize = initialLot + 0.05;
                  else
                     if(totalLotZ < initialLot * 21 + 0.63)
                        lotSize = initialLot + 0.06;
                     else
                        if(totalLotZ < initialLot * 24 + 0.84)
                           lotSize = initialLot + 0.07;
                        else
                           if(totalLotZ < initialLot * 27 + 1.08)
                              lotSize = initialLot + 0.08;
                           else
                              if(totalLotZ < initialLot * 30 + 1.35)
                                 lotSize = initialLot + 0.09;
                              else
                                 lotSize = initialLot + 0.10;
   lotSize = MathMax(lotSize, initialLot);
   return NormalizeDouble(lotSize, 2);
  }
//+------------------------------------------------------------------+
//|suma de 1 o varias positivas compensan 1 o 3 negativas => cierre
//+------------------------------------------------------------------+
void Overlap(int orderType = -1)
  {
   getTickValue();
   int    negative_overlaps = 3, ordersForMinOverlap = 5, winType     = 0, winTicket  = 0, lossType = 0, lossTicket = 0;
   double winProfit         = 0, winLot              = 0, lossProfit = 0, lossLot  = 0;
   double winTotalProfit    = 0, winTotalLot         = 0, zeroLevel  = 0;
   double overlapClose      = 0;

// Determina el valor de overlap_Pips según el número de órdenes abiertas
   if((orderType == OP_BUY  && BUYS  >= ordersForMinOverlap) || (orderType == OP_SELL && SELLS >= ordersForMinOverlap))
      overlapPipsAdded = 1;  // Cambia a 1 cuando hay al menos 5 órdenes del mismo tipo
   else
      overlapPipsAdded = overlap_Pips + overlapAdd;  // Usa valor variable según ATR
//overlapPipsAdded = overlap_Pips;  // Usa valor variable según ATR

   Position(winType, winTicket, winProfit, winLot, orderType, true);       // Orden ganadora
   Position(lossType, lossTicket, lossProfit, lossLot, orderType, false);  // Orden perdedora

   int      additionalLossTicket_3 = -1, additionalLossTicket_1 = -1;
   double   additionalLossLot_3    = 0,  additionalLossLot_1    = 0;
   double   additionalLossProfit_3 = 0,  additionalLossProfit_1 = 0;
   int      oldestLossTicket       = -1;
   datetime oldestLossTime         = 0;
   double   oldestLossProfit       = 0, oldestLossLot = 0;

   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == _Symbol && OrderType() == lossType && OrderProfit() < 0)
        {
         int magicNo = OrderMagicNumber();
         if(magicNo == magicNo_3)
           {
            additionalLossTicket_3 = OrderTicket();
            additionalLossLot_3    = OrderLots();
            additionalLossProfit_3 = OrderProfit();
           }
         else
            if(magicNo == magicNo_1)
              {
               additionalLossTicket_1 = OrderTicket();
               additionalLossLot_1    = OrderLots();
               additionalLossProfit_1 = OrderProfit();
              }
            else
               if(oldestLossTicket == -1 || OrderOpenTime() < oldestLossTime)
                 {
                  oldestLossTicket = OrderTicket();
                  oldestLossTime   = OrderOpenTime();
                  oldestLossProfit = OrderProfit();
                  oldestLossLot    = OrderLots();
                 }
        }
     }
   if(-lossProfit == 0 || winProfit == 0)
      return;

   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == _Symbol && OrderType() == winType && OrderProfit() + OrderCommission() + OrderSwap() > 0)
        {
         winTotalProfit += OrderProfit() + OrderCommission() + OrderSwap();
         winTotalLot    += OrderLots();
        }
     }
   double totalLossProfit = lossProfit + (negative_overlaps >= 2 && additionalLossTicket_3 != -1 ? additionalLossProfit_3 : 0) +
                            (negative_overlaps == 3 && additionalLossTicket_1 != -1 ? additionalLossProfit_1 : 0);
   double totalLossLot    = lossLot + (negative_overlaps >= 2 && additionalLossTicket_3 != -1 ? additionalLossLot_3 : 0) +
                            (negative_overlaps == 3 && additionalLossTicket_1 != -1 ? additionalLossLot_1 : 0);

   if(winTotalProfit >= MathAbs(totalLossProfit)) // Si las ganancias cubren las pérdidas, proceder con el cierre
     {
      if(winType == lossType)
        {
         zeroLevel = (tickValue * (winTotalLot + totalLossLot) == 0) ? 0 :
                     (winType == 0 ? NormalizeDouble(Bid - ((winTotalProfit + totalLossProfit) / (tickValue * (winTotalLot + totalLossLot)) * point), _Digits) :
                      NormalizeDouble(Ask + ((winTotalProfit + totalLossProfit) / (tickValue * (winTotalLot + totalLossLot)) * point), _Digits));
         overlapClose = (winType == 0 ? NormalizeDouble(zeroLevel + overlapPipsAdded * point, _Digits) : NormalizeDouble(zeroLevel - overlapPipsAdded * point, _Digits));
         if((winType == 0 && Bid >= overlapClose) || (winType == 1 && Ask <= overlapClose))
           {
            CloseOverlapOrders(winType, winTicket, -1);
            CloseOverlapOrders(lossType, lossTicket, -1);
            if(additionalLossTicket_3 != -1)
               CloseOverlapOrders(lossType, additionalLossTicket_3, -1);
            if(additionalLossTicket_1 != -1)
               CloseOverlapOrders(lossType, additionalLossTicket_1, -1);
            CloseAllAdditionalOrders(winType);
            zeroLevel = overlapClose = 0;
           }
        }
      //else
      //   if(buy_Sell_overlap)
      //     {
      //      zeroLevel = (tickValue * MathAbs(winTotalLot - totalLossLot) == 0) ? 0 :
      //                  (winTotalLot > totalLossLot ? (winType == 0 ? NormalizeDouble(Bid - ((winTotalProfit + totalLossProfit) / (tickValue * MathAbs(winTotalLot - totalLossLot)) * point), _Digits) :
      //                        NormalizeDouble(Ask + ((winTotalProfit + totalLossProfit) / (tickValue * MathAbs(winTotalLot - totalLossLot)) * point), _Digits)) :
      //                   (lossType == 0 ? NormalizeDouble(Bid - ((winTotalProfit + totalLossProfit) / (tickValue * MathAbs(winTotalLot - totalLossLot)) * point), _Digits) :
      //                    NormalizeDouble(Ask + ((winTotalProfit + totalLossProfit) / (tickValue * MathAbs(winTotalLot - totalLossLot)) * point), _Digits)));
      //      overlapClose = (winTotalLot > totalLossLot ? (winType == 0 ? NormalizeDouble(zeroLevel + overlapPipsAdded * point, _Digits) :
      //                      NormalizeDouble(zeroLevel - overlapPipsAdded * point, _Digits)) :
      //                      (lossType == 0 ? NormalizeDouble(zeroLevel + overlapPipsAdded * point, _Digits) :
      //                       NormalizeDouble(zeroLevel - overlapPipsAdded * point, _Digits)));
      //      bool conditionMet = (winTotalLot > totalLossLot ? (winType == 0 ? Bid >= overlapClose : Ask <= overlapClose) :
      //                           (lossType == 0 ? Bid >= overlapClose : Ask <= overlapClose));
      //      if(conditionMet)
      //        {
      //         CloseOverlapOrders(winType, winTicket, -1);
      //         if(oldestLossTicket != -1)
      //            CloseOverlapOrders(lossType, oldestLossTicket, -1);
      //         if(additionalLossTicket_3 != -1)
      //            CloseOverlapOrders(lossType, additionalLossTicket_3, -1);
      //         if(additionalLossTicket_1 != -1)
      //            CloseOverlapOrders(lossType, additionalLossTicket_1, -1);
      //         zeroLevel = overlapClose = 0;
      //        }
      //     }
     }
  }
//+------------------------------------------------------------------+
//| Función combinada para manejar tanto ganadoras como perdedoras   |
//+------------------------------------------------------------------+
void Position(int & type, int & ticket, double & profit, double & lot, int orderType = -1, bool isWin = true)
  {
   double distance = 0.0;
   type   = ticket = 0;
   profit = lot = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol && (orderType == -1 || OrderType() == orderType))
        {
         bool condition = (OrderType() == OP_BUY)
                          ? (isWin ? OrderOpenPrice() < MarketInfo(_Symbol, MODE_BID) : OrderOpenPrice() > MarketInfo(_Symbol, MODE_BID))
                          : (isWin ? OrderOpenPrice() > MarketInfo(_Symbol, MODE_ASK) : OrderOpenPrice() < MarketInfo(_Symbol, MODE_ASK));
         double currentDistance = (OrderType() == OP_BUY)
                                  ? MathAbs(OrderOpenPrice() - MarketInfo(_Symbol, MODE_BID))
                                  : MathAbs(OrderOpenPrice() - MarketInfo(_Symbol, MODE_ASK));
         if(condition && distance < currentDistance)
           {
            distance = currentDistance;
            type     = OrderType();
            ticket   = OrderTicket();
            profit   = NormalizeDouble(OrderProfit() + OrderSwap() + OrderCommission(), 2);
            lot      = OrderLots();
           }
        }
     }
   return;
  }
//+------------------------------------------------------------------+
//|  Close All Orders If Reach Profit                                |
//+------------------------------------------------------------------+
void CloseAllOrdersByProfitPositive(int orderType, double totalTakeprofit)
  {
   double currentProfit       = 0.0;
   double totalNegativeProfit = 0.0; // Total negative profit
   double totalPositiveProfit = 0.0; // Total positive profit
// Calculate total profit from matching orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol && OrderType() == orderType)
        {
         double orderProfit = OrderProfit() + OrderCommission() + OrderSwap();
         if(orderProfit <= 0)
            totalNegativeProfit += orderProfit;
         else
            totalPositiveProfit += orderProfit;

         currentProfit += orderProfit;
        }
     }
// Determine dynamic take profit
   totalTakeprofit = (orderType == OP_BUY && BUYS == 1) ? buy_profitOrder1 * ATR_factorOrder1 :
                     (orderType == OP_SELL && SELLS == 1) ? sell_profitOrder1 * ATR_factorOrder1 :
                     (mainTakeProfit > 0 && ((orderType == OP_BUY && BUYS > 1) || (orderType == OP_SELL && SELLS > 1))) ? mainTakeProfit :
                     totalTakeprofit;
// Close orders if conditions are met
   if(currentProfit >= totalTakeprofit &&
      totalPositiveProfit + totalNegativeProfit >= totalTakeprofit &&
      totalPositiveProfit > MathAbs(totalNegativeProfit))
     {
      CloseOrders(orderType);
      Print(__LINE__, (orderType == OP_BUY ? "Closed BUY orders by profit" : "Closed SELL orders by profit"));
      PrintData();
     }
  }
//+------------------------------------------------------------------+
//|  Close All Orders If Reach  Loss                                 |
//+------------------------------------------------------------------+
void CloseAllOrdersByProfitNegative(int orderType, double riskPercent)
  {
   double currentProfit  = 0.0;
   double accountBalance = AccountBalance();
   double lossThreshold  = accountBalance * riskPercent / 100;// Umbral de pérdida basado en el porcentaje de riesgo
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol && OrderType() == orderType)
        {
         double orderProfit = OrderProfit() + OrderCommission() + OrderSwap();
         currentProfit += orderProfit;                        // Sumar el profit total
        }
     }
   if(currentProfit <= -lossThreshold)                        // Cerrar órdenes si el profit negativo alcanza el umbral de pérdida
     {
      CloseOrders(orderType);
      Print(__FUNCTION__, " ", __LINE__, " Closed by loss threshold");
     }
  }
//+------------------------------------------------------------------+
//| Close Orders PARAMS : int Type  -  type of closing orders        |
//+------------------------------------------------------------------+
void CloseOrders(int Type)
  {
   int      i          = 0;
   datetime l_datetime = TimeCurrent();
   bool     closed     = false;
   while(i < OrdersTotal())
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == _Symbol && OrderType() == Type)
           {
            l_datetime = TimeCurrent();
            closed     = false;
            while(!closed && TimeCurrent() - l_datetime < 60)
              {
               closed  = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, Red);
               int err = GetLastError();
               if(err == 150)
                  return;
               Sleep(500);
               while(IsTradeContextBusy())
                  Sleep(500);
               RefreshRates();
              }
            if(closed)
              {
               i--;
              }
            else
               Print(__FUNCTION__, " ", __LINE__, " OrderClose Error: " + ErrorDescription(GetLastError()));
           }
        }
      i++;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllAdditionalOrders(int winTypeOrders)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if(OrderSymbol() == _Symbol && OrderType() == winTypeOrders && OrderProfit() + OrderCommission() + OrderSwap() > 0)
            CloseOverlapOrders(OrderType(), OrderTicket());
         Print(__LINE__, " Closed aditional orders");
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOverlapOrders(int CMD = -1, int ticket = -1, double orderLots = -1)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol && (OrderType() == CMD || CMD == -1) && (OrderTicket() == ticket || ticket == -1))
        {
         if(OrderClose(OrderTicket(), (orderLots == -1 ? OrderLots() : orderLots), OrderClosePrice(), 0, Red))
            //Print(__FUNCTION__, " ", __LINE__, " Closed overlap orders");
            Print(__LINE__, " Closed overlap orders");
         else
           {
            Print(__FUNCTION__, " ", __LINE__, " error code: ", GetLastError());
            Sleep(500);
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void getTickValue()
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == _Symbol)
        {
         if(OrderProfit() != 0)
            tickValue = MathAbs(OrderProfit() / ((OrderClosePrice() - OrderOpenPrice()) / point) / OrderLots());
        }
     }
   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PrintData()
  {
   double trend_ma_H4          = iMA(_Symbol,  PERIOD_H4, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
   double prev_trend_ma_H4     = iMA(_Symbol,  PERIOD_H4, 20, 0, MODE_SMA, PRICE_CLOSE, 1);
   double trend_rsi_H4         = iRSI(_Symbol, PERIOD_H4, 14, PRICE_CLOSE, 0);
   double prev_trend_rsi_H4    = iRSI(_Symbol, PERIOD_H4, 14, PRICE_CLOSE, 1);
   double adx_H4               = iADX(_Symbol, PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 0);
   double plus_di_H4           = iADX(_Symbol, PERIOD_H4, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
   double minus_di_H4          = iADX(_Symbol, PERIOD_H4, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
   double totalOpenBuyLotSize  = CheckLotSize(OP_BUY);                                         //lotaje acumulado ordenes buy
   double totalOpenSellLotSize = CheckLotSize(OP_SELL);                                        //lotaje acumulado ordenes sell
   double basicBuyLotSize      = NormalizeDouble(CalculateLotSize(totalOpenBuyLotSize, buy_firstLot), 2); //lotaje próxima orden sin factor
   double factorBuyLotSize     = basicBuyLotSize * ATR_LotsFactor;                             //lotaje próxima orden POR factor
   double basicSellLotSize     = NormalizeDouble(CalculateLotSize(totalOpenSellLotSize, sell_firstLot), 2);
   double factorSellLotSize    = basicSellLotSize * ATR_LotsFactor;
   Print("   fx: ",              ATR_LotsFactor, "_", NormalizeDouble(atrValue, 5),
         ",  dist check: ",      distanceCheck / point,
         ",  BUYS: ",            BUYS,
         ",  lot: ",             totalOpenBuyLotSize, " => ", basicBuyLotSize, " -> ", factorBuyLotSize,
         ",  prf: ",             buyTakeprofit,
         ", __SELLS: ",          SELLS,
         ",  lot: ",             totalOpenSellLotSize,  " => ", basicSellLotSize, " -> ", factorSellLotSize,
         ",  prf: ",             sellTakeprofit,
         ",  **ma", ((trend_ma_H4 - prev_trend_ma_H4) > 0) ? "++" : "--",
         ",  ADX", ((plus_di_H4  - minus_di_H4) > 0) ? "++" : "--", NormalizeDouble(adx_H4, 0),
         ",  RSI= ",             NormalizeDouble(trend_rsi_H4, 0),
         ",   => ",              RSIOverbought, "_", RSIOversold,
         ", atr: avg ",          NormalizeDouble(atrAvg, 5),
         ", Min ",               NormalizeDouble(atrMin, 5),
         ", Max ",               NormalizeDouble(atrMax, 5),
         ", Step ",              NormalizeDouble(ATR_Step, 5),
         ", (2)",                NormalizeDouble(ATR_Level_2, 5),
         ", (3)",                NormalizeDouble(ATR_Level_3, 5),
         ", (4)",                NormalizeDouble(ATR_Level_4, 5)
        );
  }
//+------------------------------------------------------------------+
//|   Función global que imprime mensajes solo cada X minutos       |
//+------------------------------------------------------------------+
void PrintEveryXMinutes()
  {
   static datetime lastPrintTime = 0; // Variable estática para almacenar el último tiempo de impresión
   datetime currentTime = TimeCurrent(); // Obtener la hora actual
   if(currentTime - lastPrintTime >= 5 * 60) // Verificar si han pasado X minutos
     {
      PrintData(); // Llamar a la función PrintData para imprimir la data
      lastPrintTime = currentTime; // Actualizar el tiempo del último mensaje
     }
  }
//+------------------------------------------------------------------+
//| Función para permitir o bloquear apertura de órdenes             |
//+------------------------------------------------------------------+
bool allowOrders()
  {
   datetime        currentTime    = TimeCurrent();

   int             currentDay     = DayOfWeek();
   double          currentSpread  = MarketInfo(Symbol(), MODE_SPREAD) * point;
   static datetime blockStartDate = D'2024.09.30 00:00';  // Fecha de inicio del bloqueo
   static datetime blockEndDate   = D'2024.10.01 23:59';    // Fecha de fin del bloqueo

// Verifica si el día actual está dentro del rango permitido
   bool withinDayRange = (startDay <= endDay) ?
                         (currentDay >= startDay && currentDay <= endDay) :
                         (currentDay >= startDay || currentDay <= endDay);

   if(!withinDayRange)
      return false;

// Convierte las horas de inicio y fin a tiempo del día actual
   datetime startTimeValue = StringToTime(TimeToStr(currentTime, TIME_DATE) + " " + startTime);
   datetime endTimeValue   = StringToTime(TimeToStr(currentTime, TIME_DATE) + " " + endTime);

// Ajuste para rangos cruzando la medianoche
   if(startTimeValue > endTimeValue)
     {
      if(currentTime >= startTimeValue || currentTime <= endTimeValue)
         return true;
     }
   else
      if(currentTime >= startTimeValue && currentTime <= endTimeValue)
         return true;

// Verifica si la fecha actual está dentro del rango de bloqueo
   if(currentTime >= blockStartDate && currentTime <= blockEndDate)
      return false;

// Verifica si el spread actual excede el máximo permitido
   if(currentSpread > maxSpread)
     {
      Print(__FUNCTION__, " Bloqueo: Spread actual (", DoubleToString(currentSpread, 2),
            ") excede el máximo permitido (", DoubleToString(maxSpread, 2), ").");
      return true;
     }
// Verifica si el número de órdenes abiertas excede el máximo permitido por el bróker
   int maxBrokerAllowedOrders = (int)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   if(maxBrokerAllowedOrders > 0 && OrdersTotal() >= maxBrokerAllowedOrders)
     {
      Print(__FUNCTION__, " ", __LINE__, " Order Blocking: Broker's maximum allowed order limit (", IntegerToString(maxBrokerAllowedOrders), ") reached.");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//| Normalization functions, RETURN: normalized values               |
//+------------------------------------------------------------------+
double normalizeLots(double value)
  {
   double minLots = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);
   double minStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(value < minLots)
      value = minLots;
   if(value > maxLots)
      value = maxLots;
   int digits = 1;
   if(minStep < 0.1)
      digits = 2;
   else
      if(minStep == 1)
         digits = 0;
      else
         if(minStep == 0.05)
            return(NormalizeDouble(NormalizeDouble(2 * value, 1) / 2, 2));
   return(NormalizeDouble(MathFloor(value / minStep) * minStep, digits));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double normPrice(double p, string pair = "")
  {
// Prices to open must be a multiple of ticksize
   if(pair == "")
      pair = Symbol();
   double ts = MarketInfo(pair, MODE_TICKSIZE);
   return(NormalizeDouble(MathRound(p / ts) * ts, (int)MarketInfo(pair, MODE_DIGITS)));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(string symb, double lots, int type)
  {
   double free_margin = AccountFreeMarginCheck(symb, type, lots);
//-- if there is not enough money
   if(free_margin < 0)
     {
      string oper = (type == OP_BUY) ? "Buy" : "Sell";
      Print("Not enough money for ", oper, " ", lots, " ", symb, " Error code=", GetLastError());
      return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|        **** *** Create buttons and info in chart *** ***         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long & lparam, const double & dparam, const string & sparam)
  {
   ResetLastError();
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(ObjectType(sparam) == OBJ_BUTTON)
         x_CheckButtonPress(sparam);
     }
  }
//+------------------------------------------------------------------+
void x_ShowTexts()
  {
   int Y_Distance = 45;
   int FontSize_10 = 10;
   Y_Distance += FontSize_10 * 2;

// Buy Profit Label
   ObjectCreate("ProfitB", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
   ObjectSet("ProfitB", OBJPROP_CORNER, 1);
   ObjectSet("ProfitB", OBJPROP_XDISTANCE, 20);
   ObjectSet("ProfitB", OBJPROP_YDISTANCE, Y_Distance);
   Y_Distance += FontSize_10 * 2;

// Sell Profit Label
   ObjectCreate("ProfitS", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
   ObjectSet("ProfitS", OBJPROP_CORNER, 1);
   ObjectSet("ProfitS", OBJPROP_XDISTANCE, 20);
   ObjectSet("ProfitS", OBJPROP_YDISTANCE, Y_Distance);
   Y_Distance += FontSize_10 * 2;

// Current Chart Asset Profit Label
   ObjectCreate("ChartProfit", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
   ObjectSet("ChartProfit", OBJPROP_CORNER, 1);
   ObjectSet("ChartProfit", OBJPROP_XDISTANCE, 20);
   ObjectSet("ChartProfit", OBJPROP_YDISTANCE, Y_Distance);
   Y_Distance += FontSize_10 * 2;

// Total Profit All Symbols Label
   ObjectCreate("TotalProfit", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
   ObjectSet("TotalProfit", OBJPROP_CORNER, 1);
   ObjectSet("TotalProfit", OBJPROP_XDISTANCE, 20);
   ObjectSet("TotalProfit", OBJPROP_YDISTANCE, Y_Distance);
   Y_Distance += FontSize_10 * 2;

// Spread Label
   ObjectCreate("Spread", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
   ObjectSet("Spread", OBJPROP_CORNER, 1);
   ObjectSet("Spread", OBJPROP_XDISTANCE, 20);
   ObjectSet("Spread", OBJPROP_YDISTANCE, Y_Distance);

   x_UpdateLabels();
  }
//+------------------------------------------------------------------+
void x_UpdateLabels()
  {
   double buy_profit  = x_CheckBuyProfit();
   double sell_profit = x_CheckSellProfit();
   double buy_lots    = CheckLotSize(OP_BUY);
   double sell_lots   = CheckLotSize(OP_SELL);
   double buy_orders  = BUYS;
   double sell_orders = SELLS;
   double spread      = MarketInfo(Symbol(), MODE_SPREAD);

   if(buy_lots > 0.0)
     {
      color Color_ProfitB = (buy_profit < 0.0) ? clrRed : clrLimeGreen;
      ObjectSetText("ProfitB", StringConcatenate("Buys: ", DoubleToString(buy_orders, 0),
                    ", Lot: ", DoubleToString(buy_lots, 2),
                    ", Prft: ", DoubleToString(buy_profit, 2)), 10, "Arial", Color_ProfitB);
     }
   else
      ObjectSetText("ProfitB", "Buys: 0, Lot: 0.00, Prft: 0.00", 10, "Arial", clrGray);

   if(sell_lots > 0.0)
     {
      color Color_ProfitS = (sell_profit < 0.0) ? clrRed : clrLimeGreen;
      ObjectSetText("ProfitS", StringConcatenate("Sells: ", DoubleToString(sell_orders, 0),
                    ", Lot: ", DoubleToString(sell_lots, 2),
                    ", Prft: ", DoubleToString(sell_profit, 2)), 10, "Arial", Color_ProfitS);
     }
   else
      ObjectSetText("ProfitS", "Sells: 0, Lot: 0.00, Prft: 0.00", 10, "Arial", clrGray);

// Display Chart Asset Profit (today, week, month)
   double chart_profit_today  = x_GetProfitForPeriod(Symbol(), PERIOD_D1);
   double chart_profit_week   = x_GetProfitForPeriod(Symbol(), PERIOD_W1);
   double chart_profit_month  = x_GetProfitForPeriod(Symbol(), PERIOD_MN1);
   color  Color_ProfitToday   = (chart_profit_today < 0.1) ? clrGray : clrLimeGreen;
   ObjectSetText("ChartProfit", StringConcatenate("Td : ", DoubleToString(chart_profit_today, 2),
                 ", Wk : ", DoubleToString(chart_profit_week, 0),
                 ", Mn: ", DoubleToString(chart_profit_month, 0)), 10, "Arial", Color_ProfitToday);

// Display Total Profit All Symbols (today, week, month)
   double total_profit_today     = x_GetProfitForPeriod(NULL, PERIOD_D1);
   double total_profit_week      = x_GetProfitForPeriod(NULL, PERIOD_W1);
   double total_profit_month     = x_GetProfitForPeriod(NULL, PERIOD_MN1);
   color  Color_totalProfitToday = (total_profit_today < 0.1) ? clrGray : clrLimeGreen;
   ObjectSetText("TotalProfit", StringConcatenate("TT: ", DoubleToString(total_profit_today, 2),
                 ", TW: ", DoubleToString(total_profit_week, 0),
                 ", TM: ", DoubleToString(total_profit_month, 0)), 10, "Arial", Color_totalProfitToday);
// Display Spread
   ObjectSetText("Spread", StringConcatenate("Spread:  ", DoubleToString(spread, 0)), 10, "Arial", clrOrange);
  }
//+------------------------------------------------------------------+
void x_CheckButtonPress(const string sparam)
  {
// Verificamos si el botón ha sido presionado
   if(ObjectGetInteger(0, sparam, OBJPROP_STATE))
     {
      datetime current_time = GetTickCount();  // Tiempo actual en milisegundos

      if(sparam == "Close_Buy_btn")
        {
         // Si el tiempo entre el último clic y el actual es menor a 500 ms, es un doble clic
         if(current_time - last_click_time_buy <= 500)
           {
            x_ButtonPressed(0, sparam);
            last_click_time_buy = 0;  // Reiniciar para evitar múltiples activaciones
           }
         else
            last_click_time_buy = current_time;  // Registrar el tiempo del primer clic
        }

      if(sparam == "Close_Sel_btn")
        {
         // Si el tiempo entre el último clic y el actual es menor a 500 ms, es un doble clic
         if(current_time - last_click_time_sel <= 500)
           {
            x_ButtonPressed(0, sparam);
            last_click_time_sel = 0;  // Reiniciar para evitar múltiples activaciones
           }
         else
            last_click_time_sel = current_time;  // Registrar el tiempo del primer clic
        }
      // Resetear el estado del botón después de verificarlo
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
     }
  }
//+------------------------------------------------------------------+
void x_CreateButtons()
  {
   if(!x_ButtonCreate(0, "Close_Buy_btn", 0, 188, 30, 80,
                      28, CORNER_RIGHT_UPPER, "Close Buys", "Arial", 10, White, Green, clrBlack))
      return;
   if(!x_ButtonCreate(0, "Close_Sel_btn", 0, 100, 30, 80,
                      28, CORNER_RIGHT_UPPER, "Close Sells", "Arial", 10, White, Red, clrBlack))
      return;
   ChartRedraw();
  }
//+------------------------------------------------------------------+
void x_ButtonPressed(const long chartID, const string sparam)
  {
   if(sparam == "Close_Buy_btn")
      x_Close_Buy_Button(sparam);
   if(sparam == "Close_Sel_btn")
      x_Close_Sel_Button(sparam);
   Sleep(10);
  }
//+------------------------------------------------------------------+
int x_Close_Buy_Button(const string sparam)
  {
   int ticket;
   if(OrdersTotal() == 0)
      return(0);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true)
        {
         if(OrderType() == 0 && OrderSymbol() == Symbol())
           {
            ticket = OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrNONE);
            if(ticket == -1)
               Print("Error: ", GetLastError());
            if(ticket >   0)
               Print("Position ", OrderTicket(), " closed");
           }
        }
     }
   return(0);
  }
//+------------------------------------------------------------------+
int x_Close_Sel_Button(const string sparam)
  {
   int ticket;
   if(OrdersTotal() == 0)
      return(0);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true)
        {
         if(OrderType() == 1 && OrderSymbol() == Symbol())
           {
            ticket = OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrNONE);
            if(ticket == -1)
               Print("Error: ",  GetLastError());
            if(ticket >   0)
               Print("Position ", OrderTicket(), " closed");
           }
        }
     }
   return(0);
  }
//+------------------------------------------------------------------+
bool x_ButtonCreate(const long chart_ID = 0,
                    const string name = "Button",
                    const int sub_window = 0,
                    const int x = 0,
                    const int y = 0,
                    const int width = 500,
                    const int height = 18,
                    int corner = 0,
                    const string text = "Button",
                    const string font = "Arial Bold",
                    const int font_size = 10,
                    const color clr = clrBlack,
                    const color back_clr = C'170,170,170',
                    const color border_clr = White,
                    const bool state = false,
                    const bool back = false,
                    const bool selection = false,
                    const bool hidden = true,
                    const long z_order = 0)
  {
   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_BUTTON, sub_window, 0, 0))
     {
      Print(__FUNCTION__, ": failed to create the button! Error code = ", GetLastError());
      return(false);
     }
   ObjectSetInteger(chart_ID, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_ID, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(chart_ID, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(chart_ID, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(chart_ID, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(chart_ID, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_BGCOLOR, back_clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_BORDER_COLOR, border_clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
   ObjectSetInteger(chart_ID, name, OBJPROP_STATE, state);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
   ObjectSetString(chart_ID, name, OBJPROP_TEXT, text);
   ObjectSetString(chart_ID, name, OBJPROP_FONT, font);
   return(true);
  }
//+------------------------------------------------------------------+
//| Helper function to get profit for a given period                 |
//+------------------------------------------------------------------+
double x_GetProfitForPeriod(const string symbol, const ENUM_TIMEFRAMES period)
  {
   double profit = 0.0;
   datetime from_time = iTime(symbol, period, 0);

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderCloseTime() >= from_time && (symbol == NULL || OrderSymbol() == symbol))
            profit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }
   return (profit);
  }
//+-----------------------------------------------------------------
double x_CheckBuyProfit()
  {
   double profit = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol() && OrderType() == OP_BUY)
            profit = profit + OrderProfit() + OrderSwap() + OrderCommission();
     }
   return (profit);
  }
//+------------------------------------------------------------------+
double x_CheckSellProfit()
  {
   double profit = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol() && OrderType() == OP_SELL)
            profit = profit + OrderProfit() + OrderSwap() + OrderCommission();
     }
   return (profit);
  }
//+------------------------------------------------------------------+