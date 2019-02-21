unit SM.Report;
{ Doc:
http://www.verypdf.com/document/pdf-format-reference/pg_0986.htm
https://www.adobe.com/content/dam/acom/en/devnet/acrobat/pdfs/PDF32000_2008.pdf
}
interface
  uses System.SysUtils,System.Classes,System.ZLib,System.Types,
  System.UITypes,System.StrUtils,System.Math,
  FMX.Graphics,FMX.Types, FMX.dialogs,
 {$IF DEFINED(iOS) or DEFINED(ANDROID)}
 { This is unit for android , for IOS unit you can download it from the link below
 https://andy.jgknet.de/blog/2013/10/the-return-of-the-byte-strings/ }
  System.ByteStrings,
   {$ENDIF}
  SM.PdfSection;

{
Font: https://www.oreilly.com/library/view/developing-with-pdf/9781449327903/ch04.html
https://blog.idrsolutions.com/2013/01/understanding-the-pdf-file-format-overview/#helloworld
Paper Type/Size      Centimeters       Inches      Points (inches * 72)
  Letter Width         21.59            8.5               612
  Letter Height        27.94             11               792
  A4 Width             21               8.27              596
  A4 Height            29.7             11.7              842

  POS Printer Size
  Width                7.5              2.95              213
  Height               20               7.87              567

}



Const
COURIER_FONT_SIZE = 600/1000;
ONE_CM = 28;
UNLIMITED_PAGE_HEIGHT = MaxInt;
SHAPE_MARGING = 5;
FONT_FAMILLY_WS = 'Courier';
FONT_BOLD_FAMILLY = 'Courier-Bold';
FONT_ITALIC_FAMILLY = 'Courier-Oblique';
FILE_SEETINGS = 'SMReport.INI';


Type
    TPdfString =  AnsiString;


type
    TPdfPage = Packed Record
       PageWidth,
       PageHeight,
       TopMargin,
       BottomMargin,
       LeftMargin,
       RightMargin :Integer;
       UseOnePage:   Boolean;

     Function LoadFromFile(Const AFileName:String =''):Boolean;
     procedure SaveToFile(Const AFileName:String ='');
     procedure Clear;
     Class Function Create : TPdfPage; Static;


    End;
 {needed for pdf file}
    TDocHeader = Packed Record
      Author,
      Producer,
      Subject,
      Title :TPdfString;
    End;


TSMReport = class(TComponent)
   private
     { Private declarations }
   fPdfContent:     TDocSections;
   PDF:             TMemoryStream;
   fOffsetList:     TStringList;
   fFullText:       TStringList;
   fCurrentObject:  Integer;
   fCompress:       Boolean; //Compress the pdf content
   fDocObjectsCount:Integer; //Will be incrmented after adding Pdf object
   fIDFontObj:      Integer; //Font object Without style ID
   fIDBoldFontObj:  Integer; //Font object With Blod style ID
   fIDItalicFonObj: Integer ;//Font object With Italic style ID
   fIDRessourcesObj:Integer ;//Ressources Obejct ID
   fPdfPage:        TPdfPage;
   fPageCount:      Integer;
   fDocHeader:      TDocHeader;
   fCurrentPos:     TPointf;  //The Next position of Cursor "Tm command"


   function  CharSize(F:TFont;Const Chr:Char =#0): Integer;
   function  CharsCountLine(F:TFont):Integer;

   function  EscapeSpecialChar( S :String) :String;
   function  WrapStr(Const AKey,Idx: Integer) :Boolean;
   procedure FormatTxt(AKey,Idx: Integer;S:TStrings);

   Procedure InitializePdfPage;
   procedure SetPdfPage(Value : TPdfPage);
   Procedure SetDocHeader(Value : TDocHeader);
   function  StartObject: Integer;
   procedure EndObject;
   procedure WriteToPDF(const S: TPdfString); overload ; inline;
   procedure WriteToPDF(AStream: TStream; const S: TPdfString;const AddLineBreak:Boolean =True); overload;
   procedure WriteToStream(AStream: TStream; const S: TStrings);

   procedure StartDocument;
   procedure InitDocHeader;
   procedure SetFontObject;
   procedure CreateResourcesObject;
   procedure BuildContent(out FirstObject, ObjectCount: Integer);
   procedure CreatePages(FirstRef, CountRef: Integer; out PageTreeID: Integer);
   function  CreateCatalog(PageTreeRef: Integer): Integer;
   procedure EndDocument(CatalogRef: Integer);

 protected
        { Protected declarations }
 public
        { Public declarations }
   constructor Create(AOwner: TComponent); override;
   destructor  Destroy; override;

   function    AddTxt(Txt:TStrings;
               Const FontSize :Single=12;
               const FontStyle :TFontStyles = [];
               Const Align :TTextAlign=TTextAlign.Leading;
               Const TypeShape : TTypeShape =tsNone ): Integer;
   procedure   SaveToFile(const AFileName: string;const ShowFile :Boolean=True);
   Function    LineCapacity(FontSize:Integer):Integer;
   procedure   CreateShape(const AKey :Integer; TypeShape: TTypeShape; ShapePos: TShapePosition; LHeight :Integer =1);
 Class  function  PtToCen(const Pt : Integer): Single;
 Class  function  CentToPt(const ACentim :Single ) :Integer;


 published
 { Published declarations }
   property Compress:       Boolean       read FCompress        write FCompress     default False;
   property PdfPage:        TPdfPage      read fPdfPage         write SetPdfPage;
   property DocHeader:      TDocHeader    read fDocHeader       write SetDocHeader;
   {Read only propertys}
   property CurrentPos:     TPointf       Read fCurrentPos;
   property PageCount:      Integer       read fPageCount;
   property IDFont:         Integer       read fIDFontObj       default 0;
   property IDBlodFontObj:  Integer       read fIDBoldFontObj   default 0;
   property IDItalicFonObj: Integer       read fIDItalicFonObj  default 0;
   property IDRessourcesObj:Integer       read fIDRessourcesObj default 0;
 end;
   procedure Register;

implementation
uses
    System.IOUtils,
    System.IniFiles,
 {$IFDEF ANDROID}
    Androidapi.JNI.GraphicsContentViewText,
    Androidapi.JNI.JavaTypes,
    Androidapi.JNI.Net,
    Androidapi.Helpers;
 {$ENDIF}
 {$IFDEF MSWINDOWS }
    Winapi.ShellAPI,
    Winapi.Windows;
 {$ENDIF}

{TPdfPage}

Function TPdfPage.LoadFromFile(Const AFileName:String =''):Boolean;
var F:string;
    Fs :Tinifile;
begin
//cm unit
F := IfThen(AFileName.IsEmpty,
           TPath.Combine(TPath.GetSHAREDDocumentsPath,FILE_SEETINGS),
           AFileName);
Result := FileExists(F);
Fs := TIniFile.Create( f );
try
  with Self do
  begin
   PageWidth:=    Fs.ReadInteger('PdfPage','PageWidth', 612);
   PageHeight:=   Fs.ReadInteger('PdfPage','PageHeight', 792);
   LeftMargin:=   Fs.ReadInteger('PdfPage','LeftMargin', 28);
   TopMargin:=    Fs.ReadInteger('PdfPage','TopMargin', 28);
   RightMargin:=  Fs.ReadInteger('PdfPage','RightMargin', 28);
   BottomMargin:= Fs.ReadInteger('PdfPage','BottomMargin', 28);
   UseOnePage:=   Fs.ReadBool('PdfPage','UseOnePage', False);
   end;
finally
  Fs.Free;
end;
end;

{-------------------------------------------------------------------------------}
procedure TPdfPage.SaveToFile(Const AFileName:String ='');
var F:string;
    Fs :Tinifile;
begin
F := IfThen(AFileName.IsEmpty,
           TPath.Combine(TPath.GetSHAREDDocumentsPath,FILE_SEETINGS),
           AFileName);
Fs := TIniFile.Create( f );
try
  with Self do
  begin
   Fs.WriteInteger('PdfPage','PageWidth', PageWidth);
   Fs.WriteInteger('PdfPage','PageHeight', PageHeight);
   Fs.WriteInteger('PdfPage','LeftMargin', LeftMargin);
   Fs.WriteInteger('PdfPage','TopMargin', TopMargin);
   Fs.WriteInteger('PdfPage','RightMargin', RightMargin);
   Fs.WriteInteger('PdfPage','BottomMargin', BottomMargin);
   Fs.WriteBool('PdfPage','UseOnePage', UseOnePage);
   end;
finally
  Fs.Free;
end;
end;

{-------------------------------------------------------------------------------}
procedure TPdfPage.Clear;
begin
  Self := Default(TPdfPage);
end;
{-------------------------------------------------------------------------------}

Class Function TPdfPage.Create : TPdfPage;
begin
   Result.LoadFromFile;
end;

{TSMReport}
procedure Register;
begin
 RegisterComponents('SMComponents', [TSMReport]);
end;

constructor TSMReport.Create(AOwner: TComponent);
begin
 inherited;
 PDF := TMemoryStream.Create;
 FOffsetList := TStringList.Create;
 fFullText  := TStringList.Create;
 FCompress := False;
 fPdfContent := TDocSections.Create;
 fPageCount :=0;
 InitializePdfPage;
end;
{-------------------------------------------------------------------------------}

destructor TSMReport.Destroy;
begin
 FOffsetList.Free;
 fFullText.Free;
 if Assigned(fPdfContent) then
   fPdfContent.Free;
 PDF.Free;
 inherited;
end;
{-------------------------------------------------------------------------------}

function  TSMReport.CharSize(F:TFont;Const Chr:Char =#0): Integer;
begin
{ Update this function to Get Char Width
  When Courier Font not used we must calc Font sizes by using AFM File Or
  Canvas (need hard word and lot changes)  }
   Result := Trunc(F.Size*COURIER_FONT_SIZE );
end;

{-------------------------------------------------------------------------------}
function TSMReport.CharsCountLine(F:TFont):Integer;
begin
{ Update this function to get page width capacity (Chars Count)}
With fPdfPage do
begin
    Result:= Round((PageWidth -RightMargin -LeftMargin) / (CharSize(F)))-1;
end;
end;

{-------------------------------------------------------------------------------}
function  TSMReport.EscapeSpecialChar( S :string) :String;
var
  DelimPos: Integer;
begin
Result :='';
{1. Normalize the Original S}
S:=S+' ';
DelimPos := 1;
while DelimPos < Length(S) do
begin
 if S[DelimPos] in ['\', '(', ')'] then
 begin
   Insert('\', S, DelimPos);
   Inc(DelimPos); // skip inserted char
 end else
   if S[DelimPos] = #9 {Tab} then
   begin
     { remove tab }
     Delete(S, DelimPos, 1);
     { insert the proper tab marker }
     Insert('\t', S, DelimPos);
     Inc(DelimPos); // skip "\t"
   end;
 Inc(DelimPos);
end;
 Result := S;
end;
{-------------------------------------------------------------------------------}

function WordsPos(Const PW: Integer; Text: string; Out NearestPos : Integer): TArray<Integer>;
Const Space =' ';
      Tab = #9;
var   SpaceOffset,
      TabOffset: integer;
begin
//Todo : Need More separated words chars: ", ; : - +
//The Result Value not used
NearestPos :=0;
SpaceOffset := PosEx(Space, Text, 1);
TabOffset := PosEx(#9, Text, 1);
while (SpaceOffset+TabOffset) <> 0 do
begin
  if SpaceOffset<>0 then
  begin
    SetLength(Result , Length(Result)+1 );
    Result[High(Result)] := SpaceOffset;
    SpaceOffset := PosEx(Space, Text, SpaceOffset + length(Space));
    if (SpaceOffset > NearestPos) And (SpaceOffset<=PW) then
        NearestPos := SpaceOffset
  end;
  if TabOffset<>0 then
  begin
    SetLength(Result , Length(Result)+1 );
    Result[High(Result)] := TabOffset;
    TabOffset := PosEx(Tab, Text, TabOffset + length(Tab));
    if (TabOffset > NearestPos) And (TabOffset<=PW) then
        NearestPos := TabOffset
  end;
 // NearestPos := Max(SpaceOffset,TabOffset)
end;
end;
{-------------------------------------------------------------------------------}

function TSMReport.WrapStr(Const AKey,Idx: Integer):Boolean;
var  M,PW,I:Integer;
     Itm: String;
begin
  Result := False;
  with fPdfContent.Items[AKey] do
  begin
    PW := CharsCountLine(Font);
    Itm := Trim(Text[Idx]);
    if (Length(Itm)<=PW) then
       Exit;

    //No Space char
    WordsPos(Pw,Itm,M);
    if (M<=0) OR (M>Pw) then
    begin
       while Length(Itm)>Pw do
       begin
          Text[Idx] :=Copy(Itm, 1, Pw);
          Delete(Itm,1,Pw);
          Text.Insert(Idx+1,Itm);
       end;
       Result := True;
    end Else
    begin
        Text[Idx] :=Copy(Itm, 1, M-1);
        Delete(Itm,1,M);
        Text.Insert(Idx+1,Itm);
        Result := True;
    end;
  end;
end;
{-------------------------------------------------------------------------------}

Procedure TSMReport.FormatTxt(AKey,Idx: Integer;S:TStrings);
Const NewTxt = '(%s) Tj';
      TxtPos ='1 0 0 1 %s %s Tm';
var X:Integer;
    Itm:String;
begin
  With fPdfContent.Items[AKey] do
  begin
    Itm := Trim(Text[Idx]);
    case Align of
         TTextAlign.Trailing : X := fPdfPage.PageWidth -(Length(Itm)+1)*(CharSize(Font))-PdfPage.RightMargin ;
         TTextAlign.Center :   X := ((fPdfPage.PageWidth) -(PdfPage.LeftMargin+PdfPage.RightMargin)-(length(Itm)*CharSize(Font)))div 2  + PdfPage.LeftMargin
    Else
         X := fPdfPage.LeftMargin;
    end;//case
    Itm := Format(NewTxt,[EscapeSpecialChar(Text[Idx])]);
    S.Add(Format(TxtPos,[X.ToString,fCurrentPos.Y.ToString]));
    S.Add(Itm);
    fCurrentPos.Y := fCurrentPos.Y- (Font.Size+1);
    X:= IfThen( TFontStyle.fsBold in Font.Style,-3-2);
    if (fShape.TypeShape<>tsNone) then
    begin
      if (fShape.ShapePosition<>spNone) then
          fPdfContent.UpdateEndPoint(AKey,TPointF.Create(fPdfPage.PageWidth-fPdfPage.LeftMargin,CurrentPos.Y+Font.Size-2),fShape.ShapePosition);
    end;
  end;
end;
{-------------------------------------------------------------------------------}

Function TSMReport.LineCapacity(FontSize:Integer):Integer;
begin
Result :=0;
Result := Trunc(FontSize*COURIER_FONT_SIZE );
With fPdfPage do
   Result:= Round((PageWidth -RightMargin -LeftMargin) / (Result))-1;
end;

{-------------------------------------------------------------------------------}
procedure TSMReport.CreateShape(const AKey :Integer; TypeShape: TTypeShape; ShapePos: TShapePosition; LHeight :Integer =1);
var Shp :TPdfBaseShape;
begin
   Shp.TypeShape :=     TypeShape;
   Shp.ShapePosition := ShapePos;
   Shp.StartPoint :=    TPointF.Create(0,0);
   Shp.EndPoint :=      TPointF.Create(0,0);
   Shp.LHeigt := LHeight;
   fPdfContent.SaveShape(AKey,Shp);
end;
{-------------------------------------------------------------------------------}

Procedure TSMReport.InitializePdfPage;
begin
{Default Page Is A4}
 With fPdfPage Do
 begin
   PageWidth:=       612;
   PageHeight:=      792;
   TopMargin:=    ONE_CM; {1 Cm}
   BottomMargin:= ONE_CM; {1 Cm}
   LeftMargin:=   ONE_CM; {1 Cm}
   RightMargin:=  ONE_CM; {1 Cm}
   UseOnePage:=     False;//In case of POS Printer
   fCurrentPos :=Point(LeftMargin,PageHeight-BottomMargin);
 end;
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.SetPdfPage(Value : TPdfPage);
begin
  With fPdfPage Do
  begin
    PageWidth := Value.PageWidth;
    TopMargin := Value.TopMargin;
    BottomMargin := Value.BottomMargin;
    LeftMargin := Value.LeftMargin;
    RightMargin := Value.RightMargin;
    UseOnePage := Value.UseOnePage;
    if UseOnePage then
       PageHeight:= UNLIMITED_PAGE_HEIGHT
    Else
       PageHeight:= Value.PageHeight;
  end;
end;
{-------------------------------------------------------------------------------}
procedure TSMReport.SetDocHeader(Value :TDocHeader);
begin
  With fDocHeader Do
 begin
    Author:=   Value.Author;
    Producer:= Value.Producer;
    Subject:=  Value.Subject;
    Title:=    Value.Title;
 end;
end;
{-------------------------------------------------------------------------------}

function FormatOffset(Index: Integer): string;
var  i: Integer;
begin
 Result := Format('%10d', [Index]);
 { replace spaces with zeros }
 for i := 1 to Length(Result) do
   if Result[i] = ' ' then
      Result[i] := '0';
end;
{-------------------------------------------------------------------------------}

function TSMReport.StartObject: Integer;
const
 NEW_OBJECT = '%d 0 obj';
begin
 { Save the offset of the new object and create its entry in the xref list }
 FOffsetList.Add(FormatOffset(PDF.Size) + ' 00000 n');
 { Increment object count and write the object  header to the PDF stream }
 Inc(FDocObjectsCount);
 WriteToPDF(Format(NEW_OBJECT, [FDocObjectsCount]));
 { return the Last object ID }
 Result := FDocObjectsCount;
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.EndObject;
begin
 WriteToPDF('endobj');
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.WriteToPDF(const S: TPdfString);
begin
 WriteToPDF(PDF, S);
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.WriteToPDF(AStream: TStream; const S: TPdfString;const AddLineBreak:Boolean =True);
const EOLN = #13#10;
var  pdfString: TPdfstring;
begin
 pdfString := S + IfThen(AddLineBreak,TPdfString(#13)+TPdfString(#10),'');
 AStream.Write(PAnsiChar(pdfString)^, Length(pdfString));

end;
{-------------------------------------------------------------------------------}

procedure TSMReport.WriteToStream(AStream: TStream; const S: TStrings);
var
  I: Integer;
  Str :String;
begin
 if S.Count<=0 then
   Exit;
 for I := 0 to S.Count-1 do
 begin
   WriteToPDF(AStream,S[I]);

 end;
end;

{-------------------------------------------------------------------------------}
function TSMReport.AddTxt({Parag: TParagraph} Txt:TStrings;
                    Const FontSize :Single=12;
                    const FontStyle :TFontStyles = [];
                    Const Align :TTextAlign=TTextAlign.Leading;
                    const TypeShape : TTypeShape =tsNone ):Integer;
var K,I,PS:Integer; P :TPoint;
Prg :TParagraph;

begin
Result :=-1;
if (FontSize>0) And Assigned(Txt)And
   (Align in  [TTextAlign.Center, TTextAlign.Leading, TTextAlign.Trailing]) then
    begin
       Prg.Align :=Align;
       Prg.Font  := TFont.Create;
       Prg.Font.SetSettings('Courier',FontSize,FontStyle);
       Prg.Text:= TStringList.Create;
       Prg.Text.Text := Txt.Text;
       fPdfContent.Add(Prg);
       K := fPdfContent.Count-1;
       P.X:=0;
       P.Y:=0;
       //fPdfContent.SaveShape(K,TypeShape,P,P);
       I:=0;
       while I<=fPdfContent.Items[K].Text.Count-1 do
       begin
          WrapStr(K,I);
          Inc(I);
       end;
       //Calc fPageCount
       fPageCount:= 1;
       PS := fPdfPage.TopMargin+fPdfPage.BottomMargin;
       for K := 0 to fPdfContent.Count-1 do
       begin
           PS := PS +Trunc(fPdfContent.Items[K].Text.Count*(fPdfContent.Items[K].Font.Size+1));
       end;
       if not fPdfPage.UseOnePage then
         fPageCount:= Trunc(PS div (fPdfPage.PageHeight-(fPdfPage.TopMargin+fPdfPage.BottomMargin)))+1
       Else
         fPdfPage.PageHeight := PS;
       Result := fPdfContent.Count-1;
    end
//Else raise Exception.Create('');
end;
{-------------------------------------------------------------------------------}

{$IF DEFINED(ANDROID)}
function FileNameToUri(const FileName: string): Jnet_Uri;
var
  JavaFile: JFile;
begin
  JavaFile := TJFile.JavaClass.init(StringToJString(FileName));
  Result := TJnet_Uri.JavaClass.fromFile(JavaFile);
end;
{$ENDIF}
{-------------------------------------------------------------------------------}

procedure TSMReport.StartDocument;
begin
 PDF.Clear;
 FOffsetList.Clear;
 FDocObjectsCount := 0;
 WriteToPDF('%PDF-1.2');
 if fPdfPage.UseOnePage then
   fPdfPage.PageHeight:=fPdfPage.PageHeight+CentToPt(1)
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.InitDocHeader;
begin
 StartObject;
 With fDocHeader Do
 begin
   WriteToPDF('<<');
   WriteToPDF(Format('/Author (%s)',[Author]));
   WriteToPDF(Format('/Producer (%s)',[Producer]));
   WriteToPDF(Format('/Subject (%s)',[Subject]));
   WriteToPDF(Format('/Title (%s)',[Title]));
   WriteToPDF('>>');
 end;
 EndObject;
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.SetFontObject;
begin
{ "Courier": One Font is used in all the document,
The size of this font : Wodth= 600, Heigth = Font.Size}
 StartObject;
   WriteToPDF('<< /Type /Font');
   WriteToPDF('/Subtype /Type1');
   WriteToPDF('/Name /F1');
   WriteToPDF('/BaseFont /'+FONT_FAMILLY_WS);
   WriteToPDF('/Encoding /WinAnsiEncoding');
   WriteToPDF('>>');
 EndObject;
 fIDFontObj := fDocObjectsCount;

 StartObject;
   WriteToPDF('<< /Type /Font');
   WriteToPDF('/Subtype /Type1');
   WriteToPDF('/Name /F2');
   WriteToPDF('/BaseFont /'+FONT_BOLD_FAMILLY);
   WriteToPDF('/Encoding /WinAnsiEncoding');
   WriteToPDF('>>');
 EndObject;
 fIDBoldFontObj:=  fDocObjectsCount;

  StartObject;
   WriteToPDF('<< /Type /Font');
   WriteToPDF('/Subtype /Type1');
   WriteToPDF('/Name /F3');
   WriteToPDF('/BaseFont /'+FONT_ITALIC_FAMILLY);
   WriteToPDF('/Encoding /WinAnsiEncoding');
   WriteToPDF('>>');
 EndObject;
 fIDItalicFonObj:=  fDocObjectsCount;
//there's also "Courier-BoldOblique" font
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.CreateResourcesObject;
begin
 { Set available Font (just styles) }
 StartObject;
   WriteToPDF('<< /ProcSet [ /PDF /Text]');
   WriteToPDF('/Font <<');
   WriteToPDF('/F1 '+fIDFontObj.ToString+' 0 R');
   WriteToPDF('/F2 '+fIDBoldFontObj.ToString+' 0 R');
   WriteToPDF('/F3 '+fIDItalicFonObj.ToString+' 0 R');
   WriteToPDF('>>');
   WriteToPDF('>>');
 EndObject;
 fIDRessourcesObj:= fDocObjectsCount;
end;
{-------------------------------------------------------------------------------}

Procedure TSMReport.BuildContent(out FirstObject, ObjectCount: Integer);
const _LENGTH = '<< /Length %d';
var AKey,PS, Pw, I,K,T,Pg: integer;
    S: String;
    EndPäge: Boolean;
    MS1,MS2 : TMemoryStream;
    CMS : TCompressionStream;
    A :     TPointF;
begin
{ For Each page
  1- Format texte , adding needed PDF Commands
  2- Make result inside a Pdf Stream
}

 K := 0;
 T := 0;
 ObjectCount :=fPageCount;
 FirstObject := Succ(FDocObjectsCount);
 Pg := 1;
 while Pg<= ObjectCount do
 begin
  PS := fPdfPage.TopMargin+fPdfPage.BottomMargin;
  EndPäge := False;
  fFullText.Clear;
  fFullText.Add('BT'+sLineBreak);
  fCurrentPos.X := fPdfPage.LeftMargin;
  fCurrentPos.Y := fPdfPage.PageHeight-fPdfPage.TopMargin-fPdfContent.Items[0].Font.Size;
  for AKey :=K To fPdfContent.Count-1 do
  begin
      With fPdfContent.Items[AKey] Do
      begin
        I := IfThen(TFontStyle.fsBold in Font.Style,-3,-2);
        A := TPointF.Create(fPdfPage.LeftMargin,fCurrentPos.Y+fPdfContent.Items[AKey].Font.Size+I);
      fPdfContent.UpdateStarPoint(AKey,A,fShape.ShapePosition);
        {Only one style by Item : Bold or Italic}
         if TFontStyle.fsBold in Font.Style then
            fFullText.Add('/F2 '+ IntToStr(Trunc(Font.Size))+ ' Tf')
         Else
           if TFontStyle.fsItalic in Font.Style then
              fFullText.Add('/F3 '+ IntToStr(Trunc(Font.Size))+ ' Tf')
           Else
             fFullText.Add('/F1 '+ IntToStr(Trunc(Font.Size))+ ' Tf');
        I:=T;
        while  I<= Text.Count-1 do
        begin
            if Not fPdfPage.UseOnePage then
            begin
              PS := PS +Trunc(Font.Size)+1;
              if PS<(fPdfPage.PageHeight-(fPdfPage.TopMargin+fPdfPage.BottomMargin)) then
              begin
                 FormatTxt(AKey,I,fFullText);
                 Inc(I);
              end Else
              begin  //End of the current page, so save indexs Of  fPdfContent.Items And  fPdfContent.Items[x].Text
                 T :=I;
                 K := AKey;
                 EndPäge := True;
                 Break;
              end;
            end Else
            begin
               FormatTxt(AKey,I,fFullText);
               Inc(I);
            end;
        end;//while i
        fPdfContent.DrawShape(AKey,fFullText);
       if EndPäge then
           Break;
       //fPdfContent.DrawShape(AKey,fFullText);
      end;
  End;//For Key

  fFullText.Add('ET');
   MS1 := TMemoryStream.Create;
  Try
    WriteToStream(MS1,fFullText);
    if FCompress then
    begin
       MS2 := TMemoryStream.Create;
       Try
           CMS := TCompressionStream.Create(clDefault, MS2);
         try
           CMS.CopyFrom(MS1, 0);
         finally
            CMS.Free;
         end; // CMS
         StartObject;
         WriteToPDF(Format(_LENGTH, [MS2.Size]));
         WriteToPDF('/Filter [/FlateDecode]');
         WriteToPDF('>>');
         WriteToPDF('stream');
         MS2.position :=0;
         PDF.CopyFrom(MS2,MS2.size);
         //destStream.SaveToStream(PDF);
         WriteToPDF('endstream');
         EndObject;
       Finally 
	     MS2.Free; 
	   End;
    end Else
    begin
     StartObject;
       WriteToPDF(Format(_LENGTH, [MS1.Size]));
       WriteToPDF('>>');
       WriteToPDF('stream');
       MS1.SaveToStream(PDF);
       WriteToPDF('endstream');
       EndObject;
    end;
  Finally
    MS1.Free;
  End;
  Inc(Pg);
 end;//for pg

end;
{-------------------------------------------------------------------------------}

procedure TSMReport.CreatePages(FirstRef, CountRef: Integer; out PageTreeID: Integer);
var  i: Integer;
begin
{ First create the page tree object }
PageTreeID := StartObject;
WriteToPDF('<< /Type /Pages');
WriteToPDF('/Kids [');
for i := 1 to CountRef do
  WriteToPDF(IntToStr(PageTreeID + i) + ' 0 R');
WriteToPDF(']');
WriteToPDF('/Count ' + IntToStr(CountRef)); { page count }
WriteToPDF('>>');
EndObject;
{ Create pages List }
for i := 0 to CountRef - 1 do
begin
  StartObject;
    WriteToPDF('<< /Type /Page');
    WriteToPDF('/Parent ' + IntToStr(PageTreeID) + ' 0 R');
    WriteToPDF('/MediaBox [0 0 ' + fPdfPage.PageWidth.ToString + ' ' + PdfPage.PageHeight.ToString + ']');
    WriteToPDF('/Contents ' + IntToStr(FirstRef + i) + ' 0 R');
    WriteToPDF('/Resources '+fIDRessourcesObj.ToString+' 0 R');
    WriteToPDF('>>');
  EndObject;
end;
end;
{-------------------------------------------------------------------------------}

function TSMReport.CreateCatalog(PageTreeRef: Integer): Integer;
begin
 Result := StartObject;
 WriteToPDF('<< /Type /Catalog');
 WriteToPDF('/Pages ' + IntToStr(PageTreeRef) + ' 0 R');
 WriteToPDF('>>');
 EndObject;
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.EndDocument(CatalogRef: Integer);
var
 xrefOffset: Integer;
 refCount: Integer;
begin
 xrefOffset := PDF.Size;
 WriteToPDF('xref');
 // refCount = objectCount + the constant xref entry
 refCount := Succ(FDocObjectsCount);
 WriteToPDF('0 ' + IntToStr(refCount));
 WriteToPDF('0000000000 65535 f');
 FOffsetList.SaveToStream(PDF);
 WriteToPDF('trailer');
 WriteToPDF('<< /Size ' + IntToStr(refCount + 1));
 WriteToPDF('/Root ' + IntToStr(CatalogRef) + ' 0 R');
 WriteToPDF('/Info 1 0 R');
 WriteToPDF('>>');
 WriteToPDF('startxref');
 WriteToPDF(IntToStr(xrefOffset));
 WriteToPDF('%%EOF');
end;
{-------------------------------------------------------------------------------}

procedure TSMReport.SaveToFile(const AFileName: string;const ShowFile :Boolean=True);
var PageTreeID,
    contentsFirst,
    contentsCount,
    CatalogID:     Integer;
    {$IFDEF ANDROID}
    Intent: JIntent;
    {$ENDIF}
begin
 StartDocument;
 InitDocHeader;
 SetFontObject;
 CreateResourcesObject;
 BuildContent(contentsFirst,contentsCount);
 CreatePages(contentsFirst, contentsCount, PageTreeID);
 CatalogID := CreateCatalog(PageTreeID);
 EndDocument(CatalogID);

 PDF.Position := 0;
 PDF.SaveToFile(AFileName);
if ShowFile then
   if not FileExists(AFileName) then
      raise Exception.Create( (Format('File "%s" not found.',[AFileName])))
   else
   Begin
    {$IFDEF ANDROID}
      Intent := TJIntent.JavaClass.init;
      Intent.setAction(TJIntent.JavaClass.ACTION_VIEW);
      Intent.setDataAndType(FileNameToUri(AFileName), StringToJString('application/pdf'));
      Intent.setFlags(TJIntent.JavaClass.FLAG_ACTIVITY_NO_HISTORY or
      TJIntent.JavaClass.FLAG_ACTIVITY_CLEAR_TOP);
      SharedActivity.StartActivity(Intent);
    {$ENDIF}
    {$IFDEF MSWINDOWS }
      ShellExecute(0, 'open', Pchar(AFileName),  nil,  nil,  SW_SHOWNORMAL);
    {$ENDIF}
   End;
end;

{-------------------------------------------------------------------------------}
Class  function  TSMReport.PtToCen(const Pt : Integer): Single;
begin
   Result := RoundTo(Pt/ONE_CM,-2);
end;

{-------------------------------------------------------------------------------}
Class function TSMReport.CentToPt(const ACentim :Single ) :Integer;
begin
 Result := Trunc(ONE_CM*ACentim);
end;

end.

