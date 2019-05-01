-----------------------------------------------------------------------
--  akt-commands-remove -- Remove content from keystore
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
with Ada.Text_IO;
package body AKT.Commands.Remove is

   --  ------------------------------
   --  Remove a value from the keystore.
   --  ------------------------------
   overriding
   procedure Execute (Command   : in out Command_Type;
                      Name      : in String;
                      Args      : in Argument_List'Class;
                      Context   : in out Context_Type) is
      pragma Unreferenced (Command, Name);
   begin
      if Args.Get_Count = 0 then
         AKT.Commands.Usage (Context);
      else
         Context.Open_Keystore;
         for I in 1 .. Args.Get_Count loop
            Context.Wallet.Delete (Args.Get_Argument (I));
         end loop;
      end if;

   exception
      when Keystore.Not_Found =>
         null;
   end Execute;

   --  ------------------------------
   --  Write the help associated with the command.
   --  ------------------------------
   overriding
   procedure Help (Command   : in out Command_Type;
                   Context   : in out Context_Type) is
      pragma Unreferenced (Command);
   begin
      AKT.Commands.Usage (Context);
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("akt remove: remove values from the keystore");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("Usage: remove <name>");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("  ");
   end Help;

end AKT.Commands.Remove;
