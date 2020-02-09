-----------------------------------------------------------------------
--  akt-filesystem -- Fuse filesystem operations
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
with Interfaces;
with Ada.Calendar.Conversions;

with Util.Log.Loggers;
package body AKT.Filesystem is

   use type System.St_Mode_Type;
   use type Interfaces.Unsigned_64;

   Log     : constant Util.Log.Loggers.Logger := Util.Log.Loggers.Create ("AKT.Filesystem");

   procedure Initialize (St_Buf : access System.Stat_Type;
                         Mode   : in System.St_Mode_Type);

   function To_Unix (Date : in Ada.Calendar.Time) return Interfaces.Integer_64 is
      (Interfaces.Integer_64 (Ada.Calendar.Conversions.To_Unix_Time (Date)));

   procedure Initialize (St_Buf : access System.Stat_Type;
                         Mode   : in System.St_Mode_Type) is
   begin
      St_Buf.St_Dev := 0;
      St_Buf.St_Ino := 0;
      St_Buf.St_Nlink := 1;
      St_Buf.St_Uid := 0;
      St_Buf.St_Gid := 0;
      St_Buf.St_Rdev := 0;
      St_Buf.St_Size := 0;
      St_Buf.St_Atime := 0;
      St_Buf.St_Mtime := 0;
      St_Buf.St_Ctime := 0;
      St_Buf.St_Blksize := 4096;
      St_Buf.St_Blocks := 0;
      St_Buf.St_Mode := System.Mode_T_to_St_Mode (8#700#) or Mode;
   end Initialize;

   --------------------------
   --    Get Attributes    --
   --------------------------
   function GetAttr (Path   : in String;
                     St_Buf : access System.Stat_Type) return System.Error_Type is
      Data   : constant User_Data_Type := General.Get_User_Data;
      Info   : Keystore.Entry_Info;
   begin
      Log.Debug ("Get attributes of {0}", Path);

      if Path'Length = 0 then
         return System.ENOENT;
      elsif Path = "/" then
         Initialize (St_Buf, System.S_IFDIR);
      else
         Initialize (St_Buf, System.S_IFREG);

         Info := Data.Wallet.Find (Path (Path'First + 1 .. Path'Last));

         St_Buf.St_Mode := System.Mode_T_to_St_Mode (8#600#);
         St_Buf.St_Mode := St_Buf.St_Mode or System.S_IFREG;
         St_Buf.St_Size := Interfaces.Integer_64 (Info.Size);
         St_Buf.St_Ctime := To_Unix (Info.Create_Date);
         St_Buf.St_Mtime := To_Unix (Info.Update_Date);
         St_Buf.St_Atime := St_Buf.St_Mtime;
      end if;

      return System.EXIT_SUCCESS;

   exception
      when Keystore.Not_Found =>
         return System.ENOENT;

      when others =>
         return System.EIO;
   end GetAttr;

   --------------------------
   --         MkDir        --
   --------------------------
   function MkDir (Path   : in String;
                   Mode   : in System.St_Mode_Type) return System.Error_Type is
      pragma Unreferenced (Mode);
   begin
      Log.Debug ("Mkdir {0}", Path);

      return System.EROFS;
   end MkDir;

   --------------------------
   --         Unlink       --
   --------------------------
   function Unlink (Path   : in String) return System.Error_Type is
      Data   : constant User_Data_Type := General.Get_User_Data;
   begin
      Log.Debug ("Unlink {0}", Path);

      Data.Wallet.Delete (Name => Path (Path'First + 1 .. Path'Last));
      return System.EXIT_SUCCESS;

   exception
      when Keystore.Not_Found =>
         return System.ENOENT;

      when others =>
         return System.EIO;
   end Unlink;

   --------------------------
   --          RmDir       --
   --------------------------
   function RmDir (Path   : in String) return System.Error_Type is
   begin
      Log.Debug ("Rmdir {0}", Path);

      return System.EROFS;
   end RmDir;

   --------------------------
   --        Create        --
   --------------------------
   function Create (Path   : in String;
                    Mode   : in System.St_Mode_Type;
                    Fi     : access System.File_Info_Type) return System.Error_Type is
      pragma Unreferenced (Fi, Mode);
   begin
      Log.Error ("Create {0}", Path);

      return System.EROFS;
   end Create;

   --------------------------
   --         Open         --
   --------------------------
   function Open (Path   : in String;
                  Fi     : access System.File_Info_Type) return System.Error_Type is
      pragma Unreferenced (Fi);

      Data   : constant User_Data_Type := General.Get_User_Data;
   begin
      Log.Error ("Open {0}", Path);

      if not Data.Wallet.Contains (Path (Path'First + 1 .. Path'Last)) then
         return System.ENOENT;
      else
         return System.EXIT_SUCCESS;
      end if;

   exception
      when others =>
         return System.EIO;
   end Open;

   --------------------------
   --        Release       --
   --------------------------
   function Release (Path   : in String;
                     Fi     : access System.File_Info_Type) return System.Error_Type is
      pragma Unreferenced (Fi);
   begin
      Log.Error ("Release {0}", Path);

      return System.EXIT_SUCCESS;
   end Release;


   --------------------------
   --          Read        --
   --------------------------
   function Read (Path   : in String;
                  Buffer : access Buffer_Type;
                  Size   : in out Natural;
                  Offset : in Natural;
                  Fi     : access System.File_Info_Type) return System.Error_Type is
      pragma Unreferenced (Fi);

      Data   : constant User_Data_Type := General.Get_User_Data;
      Info   : Keystore.Entry_Info;

      Buf    : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Size));
      for Buf'Address use Buffer.all'Address;
   begin
      Log.Error ("Read {0}", Path);

      Info := Data.Wallet.Find (Path (Path'First + 1 .. Path'Last));

      if Interfaces.Unsigned_64 (Offset) >= Info.Size then
         Size := 0;

      elsif Interfaces.Unsigned_64 (Offset + Size) > Info.Size then
         Size := Natural (Info.Size) - Offset;

      end if;

      Data.Wallet.Get (Name => Path (Path'First + 1 .. Path'Last),
                       Info => Info,
                       Content => Buf (1 .. Ada.Streams.Stream_Element_Offset (Size)));

      return System.EXIT_SUCCESS;

   exception
      when Keystore.Not_Found =>
         return System.EINVAL;

      when others =>
         return System.EIO;
   end Read;


   --------------------------
   --         Write        --
   --------------------------
   function Write (Path   : in String;
                   Buffer : access Buffer_Type;
                   Size   : in out Natural;
                   Offset : in Natural;
                   Fi     : access System.File_Info_Type) return System.Error_Type is
      pragma Unreferenced (Offset, Fi);
      pragma Unmodified (Size);

      Data   : constant User_Data_Type := General.Get_User_Data;

      Buf    : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Size));
      for Buf'Address use Buffer.all'Address;
   begin
      Log.Debug ("Write {0}", Path);

      Data.Wallet.Set (Name => Path (Path'First + 1 .. Path'Last),
                       Kind => Keystore.T_BINARY,
                       Content => Buf);

      return System.EXIT_SUCCESS;

   exception
      when Keystore.Not_Found =>
         return System.EINVAL;

      when others =>
         return System.EIO;
   end Write;


   --------------------------
   --       Read Dir       --
   --------------------------
   function ReadDir (Path   : in String;
                     Filler : access procedure (Name     : String;
                                                St_Buf   : System.Stat_Access;
                                                Offset   : Natural);
                     Offset : in Natural;
                     Fi     : access System.File_Info_Type) return System.Error_Type is
      pragma Unreferenced (Offset, Fi);

      Data   : constant User_Data_Type := General.Get_User_Data;
      List   : Keystore.Entry_Map;
      Iter   : Keystore.Entry_Cursor;
      St_Buf : aliased System.Stat_Type;
   begin
      Log.Error ("Read directory {0}", Path);

      Initialize (St_Buf'Unchecked_Access, System.S_IFDIR);
      Filler (".", St_Buf'Unchecked_Access, 0);
      Filler ("..", St_Buf'Unchecked_Access, 0);

      Data.Wallet.List (Content => List);
      Iter := List.First;
      while Keystore.Entry_Maps.Has_Element (Iter) loop
         declare
            Name : constant String := Keystore.Entry_Maps.Key (Iter);
            Item : constant Keystore.Entry_Info := Keystore.Entry_Maps.Element (Iter);
         begin
            Initialize (St_Buf'Unchecked_Access, System.S_IFREG);
            St_Buf.St_Size := Interfaces.Integer_64 (Item.Size);
            St_Buf.St_Ctime := To_Unix (Item.Create_Date);
            St_Buf.St_Mtime := To_Unix (Item.Update_Date);
            St_Buf.St_Blocks := Interfaces.Integer_64 (Item.Block_Count);
            Filler.all (Name, St_Buf'Unchecked_Access, 0);
         end;
         Keystore.Entry_Maps.Next (Iter);
      end loop;

      return System.EXIT_SUCCESS;

   exception
      when Keystore.Not_Found =>
         return System.ENOENT;

      when others =>
         return System.EIO;
   end ReadDir;

   function Truncate (Path   : in String;
                      Size   : in Natural)
                      return System.Error_Type is
      Data   : constant User_Data_Type := General.Get_User_Data;
   begin
      return System.EXIT_SUCCESS;
   end Truncate;

end AKT.Filesystem;
