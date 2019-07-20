-----------------------------------------------------------------------
--  akt-commands-create -- Create a keystore
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
with AKT.Passwords.Files;
with AKT.Passwords.Unsafe;
with AKT.Passwords.Input;
package body AKT.Commands.Password is

   use GNAT.Strings;

   --  ------------------------------
   --  Create the keystore file.
   --  ------------------------------
   overriding
   procedure Execute (Command   : in out Command_Type;
                      Name      : in String;
                      Args      : in Argument_List'Class;
                      Context   : in out Context_Type) is
      pragma Unreferenced (Name, Args);

      New_Password_Provider : AKT.Passwords.Provider_Access;
   begin
      if Command.Password_File'Length > 0 then
         New_Password_Provider := Passwords.Files.Create (Command.Password_File.all);
      elsif Context.Unsafe_Password'Length > 0 then
         New_Password_Provider := Passwords.Unsafe.Create (Command.Unsafe_Password.all);
      else
         New_Password_Provider := AKT.Passwords.Input.Create (False);
      end if;

      Context.Change_Password (New_Password => New_Password_Provider.Get_Password,
                               Slot         => 0);
   end Execute;

   --  ------------------------------
   --  Setup the command before parsing the arguments and executing it.
   --  ------------------------------
   procedure Setup (Command : in out Command_Type;
                    Config  : in out GNAT.Command_Line.Command_Line_Configuration;
                    Context : in out Context_Type) is
      pragma Unreferenced (Context);

      package GC renames GNAT.Command_Line;
   begin
      GC.Define_Switch (Config => Config,
                        Output => Command.Password_File'Access,
                        Long_Switch => "--passfile=",
                        Argument => "PATH",
                        Help   => "Read the file that contains the password");
      GC.Define_Switch (Config => Config,
                        Output => Command.Unsafe_Password'Access,
                        Long_Switch => "--passfd=",
                        Argument => "NUM",
                        Help   => "Read the password from the pipe with"
                          & " the given file descriptor");
      GC.Define_Switch (Config => Config,
                        Output => Command.Unsafe_Password'Access,
                        Long_Switch => "--passsocket=",
                        Help   => "The password is passed within the socket connection");
      GC.Define_Switch (Config => Config,
                        Output => Command.Password_Env'Access,
                        Long_Switch => "--passenv=",
                        Argument => "NAME",
                        Help   => "Read the environment variable that contains"
                        & " the password (not safe)");
      GC.Define_Switch (Config => Config,
                        Output => Command.Unsafe_Password'Access,
                        Switch => "-p:",
                        Long_Switch => "--password=",
                        Help   => "The password is passed within the command line (not safe)");
   end Setup;

   --  ------------------------------
   --  Write the help associated with the command.
   --  ------------------------------
   overriding
   procedure Help (Command   : in out Command_Type;
                   Context   : in out Context_Type) is
      pragma Unreferenced (Command, Context);
   begin
      Ada.Text_IO.Put_Line ("akt change-password: change the wallet password");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("Usage: akt change-password [--counter-range min:max]");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("  Changes an existing password.");
      Ada.Text_IO.Put_Line ("  By default the PBKDF2 iteration counter is in range"
                            & " 500000..1000000");
      Ada.Text_IO.Put_Line ("  You can change this range by using the `--counter-range` option.");
      Ada.Text_IO.Put_Line ("  High values provide best password protection at the expense"
                              & " of speed.");
   end Help;

end AKT.Commands.Password;