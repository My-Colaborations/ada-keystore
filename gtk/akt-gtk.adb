-----------------------------------------------------------------------
--  akt-gtk -- Ada Keystore Tool GTK Application
--  Copyright (C) 2019 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------

with Gtk.Widget; use Gtk;
with AKT.Windows;
procedure AKT.Gtk is
   Main        : Widget.Gtk_Widget;
   Application : aliased AKT.Windows.Application_Type;
begin
   AKT.Configure_Logs (Debug   => True,
                       Verbose => True);
   Application.Initialize_Widget (Main);
   Application.Main;
end AKT.Gtk;
