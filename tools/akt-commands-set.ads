-----------------------------------------------------------------------
--  akt-commands-set -- Set content in keystore
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
with AKT.Commands.Drivers;
private package AKT.Commands.Set is

   type Command_Type is new AKT.Commands.Drivers.Command_Type with private;

   --  Insert a new value in the keystore.
   overriding
   procedure Execute (Command   : in out Command_Type;
                      Name      : in String;
                      Args      : in Argument_List'Class;
                      Context   : in out Context_Type);

   --  Setup the command before parsing the arguments and executing it.
   overriding
   procedure Setup (Command : in out Command_Type;
                    Config  : in out GNAT.Command_Line.Command_Line_Configuration;
                    Context : in out Context_Type);

   --  Write the help associated with the command.
   overriding
   procedure Help (Command   : in out Command_Type;
                   Context   : in out Context_Type);

private

   type Command_Type is new AKT.Commands.Drivers.Command_Type with record
      File : aliased GNAT.Strings.String_Access;
   end record;

end AKT.Commands.Set;
