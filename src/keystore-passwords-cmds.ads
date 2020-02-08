-----------------------------------------------------------------------
--  keystore-passwords-cmds -- External command based password provider
--  Copyright (C) 2019, 2020 Stephane Carrez
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

package Keystore.Passwords.Cmds is

   MAX_PASSWORD_LENGTH : constant := 1024;

   --  Create a password provider that runs a command to get the password.
   function Create (Command : in String) return Provider_Access;

end Keystore.Passwords.Cmds;
