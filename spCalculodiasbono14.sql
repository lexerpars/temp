create  procedure spCalculodiasbono14(@idpersonal varchar (10))    
as    
declare     
 @mes varchar(4),--Variable para recuperar el mes del último pago.    
 @anno varchar(4),--Variable a la que se le asigna el año para el cálculo de BONO 14.    
 @fechabono varchar(12),-- Variable que devuelve la fecha total para el cálculo de BONO 14.    
 @fechabonoA datetime,    
 @fechaingreso datetime,    
 @dias integer,  
 @PagarBonoPerAc integer  
 SELECT @PagarBonoPerAc=(SELECT valor FROM personalpropvalor WHERE Propiedad = 'Pagar Bono 14 periodo Actual?' AND cuenta=@idpersonal)  
    
   
   
 if @PagarBonoPerAc=1     
  begin    
   set @mes=(select (MONTH(ultimopago)+1) from Personal where Personal=@idpersonal AND ultimopago is not null )        
  end    
 ELSE  
  BEGIN  
   set @mes=(select MONTH(ultimopago) from Personal where Personal=@idpersonal AND ultimopago is not null )  
  END  
  --Con variable en el sp    
 set @fechaingreso= (select FechaAntiguedad from Personal where Personal=@idpersonal)    
if @mes>=7     
  begin    
   /*Si entra acá el año será el mismo que el AÑO del "ULTIMO PAGO"*/       
   set @anno=(select year(UltimoPago)from Personal where Personal=@idpersonal AND ultimopago is not null) -- Con variable en el sp        
  end    
 else    
  begin       
   /*Si entra acá se le resta un año al "ULTIMO PAGO"*/       
   set @anno=(select (YEAR(ultimopago)-1) from Personal where Personal=@idpersonal AND ultimopago is not null) --Con variable en el sp       
  end    
 set @fechabono=@anno+'0701'    
 if @fechaingreso>=@fechabono    
  begin    
   set @fechabonoA=@fechaingreso    
  end    
 else    
  begin    
   set @fechabonoA=@fechabono    
  end    
 set @dias=(select DATEDIFF(dd,@fechabonoA,Personal.FechaBaja)+1 from Personal where Personal=@idpersonal and UltimoPago is Not null)    
 select @dias