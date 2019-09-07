-----------------------------------------------------------------------
--  keystore-repository-entries -- Repository management for the keystore
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
with Util.Log.Loggers;
with Keystore.Logs;

with Keystore.Repository.Entries;
package body Keystore.Repository.Keys is

   use type Interfaces.Unsigned_32;

   Log : constant Util.Log.Loggers.Logger
     := Util.Log.Loggers.Create ("Keystore.Repository.Keys");

   procedure Load_Next_Keys (Manager  : in out Wallet_Manager;
                             Iterator : in out Data_Key_Iterator) is
      Index : Interfaces.Unsigned_32;
      Count : Interfaces.Unsigned_16;
      Offset : IO.Block_Index;
   begin
      Iterator.Directory := Wallet_Data_Key_List.Element (Iterator.Key_Iter).Directory;
      Entries.Load_Directory (Manager, Iterator.Directory, Iterator.Current);

      Iterator.Key_Header_Pos := Iterator.Directory.Key_Pos;
      Iterator.Key_Last_Pos := Iterator.Directory.Key_Pos;
      Iterator.Key_Count := 0;

      --  Scan each data key entry.
      Offset := IO.Block_Index'Last;
      while Offset > Iterator.Key_Header_Pos loop
         Offset := Offset - DATA_KEY_HEADER_SIZE;
         Iterator.Current.Pos := Offset;
         Index := Marshallers.Get_Unsigned_32 (Iterator.Current);
         Count := Marshallers.Get_Unsigned_16 (Iterator.Current);
         if Index = Interfaces.Unsigned_32 (Iterator.Entry_Id) then
            Iterator.Key_Header_Pos := Offset;
            Iterator.Current.Pos := Offset;
            Iterator.Key_Count := Count;
            Iterator.Count := Count;
            return;
         end if;

         Offset := Offset - Key_Slot_Size (Count);
      end loop;
   end Load_Next_Keys;

   procedure Initialize (Manager  : in out Wallet_Manager;
                         Iterator : in out Data_Key_Iterator;
                         Item     : in Wallet_Entry_Access) is
   begin
      Iterator.Key_Iter := Item.Data_Blocks.First;
      Iterator.Entry_Id := Item.Id;
      Iterator.Current_Offset := 0;
      Iterator.Key_Pos := IO.Block_Index'Last;
      Iterator.Count := 0;
      Iterator.Item := Item;
      if Wallet_Data_Key_List.Has_Element (Iterator.Key_Iter) then
         Load_Next_Keys (Manager, Iterator);
      else
         Iterator.Directory := null;
      end if;
   end Initialize;

   function Has_Data_Key (Iterator : in Data_Key_Iterator) return Boolean is
   begin
      return Iterator.Directory /= null;
   end Has_Data_Key;

   function Is_Last_Key (Iterator : in Data_Key_Iterator) return Boolean is
   begin
      return Iterator.Count = 0 and Iterator.Directory /= null;
   end Is_Last_Key;

   procedure Next_Data_Key (Manager  : in out Wallet_Repository;
                            Iterator : in out Data_Key_Iterator) is
      Pos : IO.Block_Index;
   begin
      loop
         --  Extract the next data key from the current directory block.
         if Iterator.Count > 0 then
            Iterator.Current.Pos := Iterator.Current.Pos - DATA_KEY_ENTRY_SIZE;
            Pos := Iterator.Current.Pos;
            Iterator.Data_Block := Marshallers.Get_Storage_Block (Iterator.Current);
            Iterator.Data_Size := Marshallers.Get_Buffer_Size (Iterator.Current);
            Iterator.Key_Pos := Iterator.Current.Pos;
            Iterator.Current.Pos := Pos;
            Iterator.Count := Iterator.Count - 1;
            return;
         end if;

         if not Wallet_Data_Key_List.Has_Element (Iterator.Key_Iter) then
            Iterator.Directory := null;
            return;
         end if;

         Wallet_Data_Key_List.Next (Iterator.Key_Iter);
         if not Wallet_Data_Key_List.Has_Element (Iterator.Key_Iter) then
            Iterator.Directory := null;
            return;
         end if;

         Load_Next_Keys (Manager, Iterator);
      end loop;
   end Next_Data_Key;

   procedure Mark_Data_Key (Iterator : in Data_Key_Iterator;
                            Mark     : in out Data_Key_Marker) is
   begin
      Mark.Directory := Iterator.Directory;
      Mark.Key_Header_Pos := Iterator.Key_Header_Pos;
      Mark.Key_Count := Iterator.Count;
   end Mark_Data_Key;

   procedure Delete_Key (Manager  : in out Wallet_Repository;
                         Iterator : in out Data_Key_Iterator;
                         Mark     : in out Data_Key_Marker) is
      Buf  : constant Buffers.Buffer_Accessor := Iterator.Current.Buffer.Data.Value;
      Key_Start_Pos : IO.Block_Index;
      Next_Iter     : Wallet_Data_Key_List.Cursor;
      Key_Pos       : IO.Block_Index;
      Del_Count     : Interfaces.Unsigned_16;
      Del_Size      : IO.Buffer_Size;
   begin
      if Mark.Key_Count = Iterator.Key_Count then
         --  Erase header + all keys
         Del_Count := Iterator.Key_Count;
         Del_Size := Key_Slot_Size (Del_Count) + DATA_KEY_HEADER_SIZE;
      else
         --  Erase some data keys but not all of them (the entry was updated and truncated).
         Del_Count := Iterator.Key_Count - Mark.Key_Count;
         Del_Size := Key_Slot_Size (Del_Count);
         Iterator.Current.Pos := Mark.Key_Header_Pos + 4;
         Marshallers.Put_Unsigned_16 (Iterator.Current, Mark.Key_Count);
      end if;
      Key_Start_Pos := Iterator.Key_Header_Pos - Key_Slot_Size (Iterator.Key_Count);

      Key_Pos := Iterator.Directory.Key_Pos;
      if Key_Pos < Key_Start_Pos then
         Buf.Data (Key_Pos + Del_Size .. Key_Start_Pos + Del_Size - 1)
           := Buf.Data (Key_Pos .. Key_Start_Pos - 1);
      end if;
      Buf.Data (Key_Pos .. Key_Pos + Del_Size - 1) := (others => 0);

      Iterator.Directory.Key_Pos := Key_Pos + Del_Size;
      if Iterator.Directory.Count > 0 or Iterator.Directory.Key_Pos < IO.Block_Index'Last then
         Iterator.Current.Pos := IO.BT_DATA_START + 4;
         Marshallers.Put_Block_Index (Iterator.Current, Iterator.Directory.Key_Pos);

         Manager.Modified.Include (Iterator.Current.Buffer.Block, Iterator.Current.Buffer.Data);
      else
         Manager.Stream.Release (Iterator.Directory.Block);
      end if;

      if Mark.Key_Count = Iterator.Key_Count then
         Next_Iter := Wallet_Data_Key_List.Next (Iterator.Key_Iter);
         Iterator.Item.Data_Blocks.Delete (Iterator.Key_Iter);
         Iterator.Key_Iter := Next_Iter;
      else

         if not Wallet_Data_Key_List.Has_Element (Iterator.Key_Iter) then
            Iterator.Directory := null;
            return;
         end if;

         Wallet_Data_Key_List.Next (Iterator.Key_Iter);
      end if;

      if not Wallet_Data_Key_List.Has_Element (Iterator.Key_Iter) then
         Iterator.Directory := null;
         return;
      end if;

      Load_Next_Keys (Manager, Iterator);
      Mark_Data_Key (Iterator, Mark);
   end Delete_Key;

   procedure Allocate_Key_Slot (Manager    : in out Wallet_Repository;
                                Iterator   : in out Data_Key_Iterator;
                                Data_Block : in IO.Storage_Block;
                                Size       : in IO.Buffer_Size;
                                Key_Pos    : out IO.Block_Index;
                                Key_Block  : out IO.Storage_Block) is
      Key_Start : IO.Block_Index;
      Key_Last  : IO.Block_Index;
   begin
      if Iterator.Directory = null or else Iterator.Directory.Available < DATA_KEY_ENTRY_SIZE then
         Entries.Find_Directory_Block (Manager, DATA_KEY_ENTRY_SIZE * 4, Iterator.Directory);
         Iterator.Directory.Available := Iterator.Directory.Available + DATA_KEY_ENTRY_SIZE * 4;
         if Iterator.Directory.Count > 0 then
            Entries.Load_Directory (Manager, Iterator.Directory, Iterator.Current);
         else
            Iterator.Current.Buffer := Buffers.Allocate (Iterator.Directory.Block);

            --  Prepare the new directory block.
            --  Fill the new block with random values or with zeros.
            if Manager.Randomize then
               Manager.Random.Generate (Iterator.Current.Buffer.Data.Value.Data);
            else
               Iterator.Current.Buffer.Data.Value.Data := (others => 0);
            end if;
            Marshallers.Set_Header (Into => Iterator.Current,
                                    Tag  => IO.BT_WALLET_DIRECTORY,
                                    Id   => Manager.Id);
            Marshallers.Put_Unsigned_32 (Iterator.Current, 0);
            Marshallers.Put_Block_Index (Iterator.Current, IO.Block_Index'Last);
         end if;
         Iterator.Key_Header_Pos := Iterator.Directory.Key_Pos - DATA_KEY_HEADER_SIZE;
         Iterator.Directory.Available := Iterator.Directory.Available - DATA_KEY_HEADER_SIZE;
         Iterator.Directory.Key_Pos := Iterator.Key_Header_Pos;
         Iterator.Key_Last_Pos := Iterator.Directory.Key_Pos;
         Iterator.Current.Pos := Iterator.Key_Header_Pos;
         Iterator.Key_Count := 0;
         Marshallers.Put_Unsigned_32 (Iterator.Current,
                                      Interfaces.Unsigned_32 (Iterator.Entry_Id));
         Marshallers.Put_Unsigned_16 (Iterator.Current, 0);
         Marshallers.Put_Unsigned_32 (Iterator.Current, 0);
         Iterator.Item.Data_Blocks.Append (Wallet_Data_Key_Entry '(Iterator.Directory, 0));
      end if;

      declare
         Buf       : constant Buffers.Buffer_Accessor := Iterator.Current.Buffer.Data.Value;
      begin
         --  Shift keys before the current slot.
         Key_Start := Iterator.Directory.Key_Pos;
         Key_Last := Iterator.Key_Last_Pos;
         if Key_Last /= Key_Start then
            Buf.Data (Key_Start - DATA_KEY_ENTRY_SIZE .. Key_Last - 1)
              := Buf.Data (Key_Start .. Key_Last - 1);
         end if;

         --  Grow the key slot area by one key slot.
         Iterator.Key_Last_Pos := Iterator.Key_Last_Pos - DATA_KEY_ENTRY_SIZE;
         Iterator.Directory.Key_Pos := Key_Start - DATA_KEY_ENTRY_SIZE;
         Iterator.Directory.Available := Iterator.Directory.Available - DATA_KEY_ENTRY_SIZE;
         Iterator.Current.Pos := IO.BT_DATA_START + 4;
         Marshallers.Put_Block_Index (Iterator.Current, Iterator.Directory.Key_Pos);

         --  Insert the new data key.
         Iterator.Key_Count := Iterator.Key_Count + 1;
         Iterator.Current.Pos := Iterator.Key_Header_Pos + 4;
         Marshallers.Put_Unsigned_16 (Iterator.Current, Iterator.Key_Count);
         Iterator.Current.Pos := Iterator.Key_Header_Pos - Key_Slot_Size (Iterator.Key_Count);
         Marshallers.Put_Storage_Block (Iterator.Current, Data_Block);
         Marshallers.Put_Buffer_Size (Iterator.Current, Size);
         Iterator.Key_Pos := Iterator.Current.Pos;

         Manager.Modified.Include (Iterator.Current.Buffer.Block, Iterator.Current.Buffer.Data);

         Key_Pos := Iterator.Key_Pos;
         Key_Block := Iterator.Current.Buffer.Block;
      end;
   end Allocate_Key_Slot;

   procedure Update_Key_Slot (Manager    : in out Wallet_Repository;
                              Iterator   : in out Data_Key_Iterator;
                              Size       : in IO.Buffer_Size) is
   begin
      pragma Assert (Iterator.Directory /= null);

      if Iterator.Data_Size /= Size then
         Iterator.Current.Pos := Iterator.Key_Pos - 2;
         Marshallers.Put_Unsigned_16 (Iterator.Current, Interfaces.Unsigned_16 (Size));

         Manager.Modified.Include (Iterator.Current.Buffer.Block, Iterator.Current.Buffer.Data);
      end if;
   end Update_Key_Slot;

end Keystore.Repository.Keys;