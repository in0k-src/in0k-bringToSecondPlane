unit uBringToSecond_GtkX;

//--- Схема работы функции на примере ------------------------ [ in0k (c) 2018 ]
//
//     Z-Index
//
//     0    Wnd00              +-> Wnd_A                        Wnd_A
//     1    Wnd01              |   Wnd00                    +-> Wnd_B
//     2     ...               |   Wnd01                    |   Wnd00
//     3     ...               |    ...                     |   Wnd01
//    ...    ...               |    ...                     |
//     N    Wnd_A.bringToFront-^    ...                     |
//     M     ...                   bringToSecond(Wnd_B)-----^
//    ...    ...                    ...
//    ...............................................................
//    DeskTop DeskTop DeskTop DeskTop DeskTop DeskTop DeskTop DeskTop
//
//----------------------------------------------------------------------------//
// "НАТИвНаЯ" реализация, НЕ моргает (если НЕ из под Windows).
//----------------------------------------------------------------------------//
   {%region --- проверка совместимости ------------------------ /fold}
    {$IF not(DEFINED(LCLgtk2) or DEFINED(LCLgtk3))}
    {$ErrOr 'WRONG `WidgetSet`! Unit must be used only with `LCLgtk2` or `LCLgtk3`!'}
    {$endIF}
   {%endregion}
   {%region --- подсказки про СИСТЕМНЫЕ библиотеки ------------ /fold}
    {$If DEFINED(MSWINDOWS)}
    {$note ------------------------------------------------------}
    {$note   Under "Windows" system it doesn't work very well.   }
    {$note   For best results, try use `bringToSecond_WIN.pas`.  }
    {$note ------------------------------------------------------}
    {$endIF}
   {%endregion}
//----------------------------------------------------------------------------//

interface

uses
  uB2SP_SzOW,
  uB2SP_SzOF,
  Forms;

procedure bringToSecond(const form:TCustomForm); {$ifOPT D-}inline;{$endIf}

implementation

{%region --- #0. gdk_window_restack and inLine functions --------- /fold }
//
// определить функцию `gdk_window_restack`
// получить Handle окна в НАТИВНЫХ понятиях конкретного GTK

{$IF DEFINED(LCLgtk2)} //----------------------------------------------- LCLgtk2
{% TESTed in0k 20190530 i386-win32-gtk2 Lazarus:2.0.0.4 FPC:3.0.4             %}
{% TESTed in0k 20190530 x86_64-linux-gtk2 Lazarus:2.0.2.0 FPC:3.0.4           %}
uses gdk2,gtk2,glib2;

// она ЕСТЬ, но НЕ объявлена :-)
procedure gdk_window_restack(window:PGdkWindow; sibling:PGdkWindow; above:gboolean); cdecl; external gdklib;

function _wndHNDL_GET_(const form:TCustomForm):PGdkWindow; {$ifOPT D-}inline;{$endIf}
begin {$ifOPT D+}
      Assert(Assigned(form),'`form`: must be defined');
      Assert(form.HandleAllocated,'`form.Handle`: not Allocated');
      {$endIf}
    result:={%H-}PGtkWidget(form.Handle)^.window;
    {$ifOPT D+} Assert(Assigned(result),'`form:PGdkWindow` NOT found'); {$endIf}
end;

{$elseIF DEFINED(LCLgtk3)} //------------------------------------------- LCLgtk3
{% TESTed in0k 20190530 x86_64-linux-gtk3 (alpha) Lazarus:2.0.2.0 FPC:3.0.4   %}
uses gtk3widgets, LazGdk3;

function _wndHNDL_GET_(const form:TCustomForm):PGdkWindow; {$ifOPT D-}inline;{$endIf}
begin {$ifOPT D+}
      Assert(Assigned(form),'`form`: must be defined');
      Assert(form.HandleAllocated,'`form.Handle`: not Allocated');
      {$endIf}
    result:=TGtk3Window(form.Handle).Widget^.window;
    {$ifOPT D+} Assert(Assigned(result),'`form:PGdkWindow` NOT found'); {$endIf}
end;

//------------------------------------------------------------------------------
{$else} // что-то пошло не так :-( // Сообщим об ошибке, поклянчим фидБек
    {$error Target platform not supported!             }
    {$note  Function `_wndHNDL_GET_` NOT define.       }
    {$note  Please, report this error to the developer.}     s
{$endIF}

{%endregion -------------------------------------------------------------------}

{%region --- #1. ОСНОВНАЯ функция, ради неё все и затевается ----- /fold }

// установить порядок следования окон в `Z-Index`
// @prm target целевое окно, относительно которого проводим перемещение
// @prm wndNXT перемещаемое окно
// @res true   перемещение УДАЛОСЬ :-)
//----------
// в результате выполнения: (wndTOP)target -> wndNXT .. DeskTop
procedure _wndZOrder_SET_(const target,wndNXT:PGdkWindow); {$ifOPT D-}inline;{$endIf}
begin {$ifOPT D+}
      Assert(Assigned(target),'`target`: must be defined');
      Assert(Assigned(wndNXT),'`wndNXT`: must be defined');
      {$endIf}
    // используем реальный GTK инструментарий ... перемещаем
    {$IF DEFINED(MSWINDOWS)} // под виндой ОПЯТЬ все криво :-(
        {$warning --------------------------------------------------}
        {$warning `gdk_window_restack` INCORRECTLY works in WINDOWS }
        {$warning  I Мust use a double call.                        }
        {$warning  Which is equivalent to bringToSecond_LCL.        }
        {$warning --------------------------------------------------}
        {$warning  For best results, try use `bringToSecond_WIN.pas`}
        {$warning --------------------------------------------------}
        gdk_window_restack(target,wndNXT,false);
        gdk_window_restack(wndNXT,target,false);
    {$else}
        gdk_window_restack(wndNXT,target,false);
    {$endIf}
end;

{%endregion -------------------------------------------------------------}

{%region --- #2. Вызов ОСНОВАНОЙ функции ------------------------- /fold }

// расположить `Формы` в порядке `zIndex` (fTop -> form .. DeskTop).
procedure _set_zIndex_in_Order_(const fTop,form:TCustomForm); {$ifOPT D-}inline;{$endIf}
begin {$ifOPT D+}
      Assert(Assigned(fTop),'`fTop`: must be defined');
      Assert(Assigned(form),'`form`: must be defined');
      {$endIf}
   _wndZOrder_SET_(_wndHNDL_GET_(fTop),_wndHNDL_GET_(form));
end;

// переместить форму на "Второй План"
// @prm fTop форма, которая в настоящий момент находится на переднем плане
// @prm form перемещаемая форма
procedure _bringToSecond_(const fTop,form:TCustomForm); {$ifOPT D-}inline;{$endIf}
var list:tListFT2F;
begin {$ifOPT D+}
      Assert(Assigned(form),'`form`: must be defined');
      Assert(Assigned(fTop),'`fTop`: must be defined');
      Assert(SzOW_form_is_TOP_inZOrder(fTop),'`fTop`: must be TOP form in the app');
      {$endIf}
    // Особенности см. `b2sp_SzOF.#1`
    list:=SzOF_listFT2F_make (form);
   _set_zIndex_in_Order_(fTop,form);
    SzOF_listFT2F_zFIX  (fTop,form,list);
    SzOF_listFT2F_free  (list);
end;

{%endregion -------------------------------------------------------------}

// Переместить форму на "Второй План"
procedure bringToSecond(const form:TCustomForm);
begin {$ifOPT D+} Assert(Assigned(form),'`form`: must be defined'); {$endIf}
    if SzOW_SecondPlane_possible(form)
    then _bringToSecond_(SzOW_get_topForm_inZOrder,form);
end;

end.

