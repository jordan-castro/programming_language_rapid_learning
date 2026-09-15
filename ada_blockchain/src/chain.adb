with Ada.Containers.Vectors;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Indefinite_Ordered_Maps;
with GNAT.SHA256;
with Ada.Calendar;
with Ada.Calendar.Formatting;

procedure Chain is
   type Block is record
      Timestamp : Long_Integer := 0;
      Last_Hash : Unbounded_String := To_Unbounded_String ("");
      Hash : Unbounded_String := To_Unbounded_String ("");
      Data : Unbounded_String := To_Unbounded_String ("");
      Difficulty : Integer := 0;
      Nonce : Integer := 0;
      Number : Integer := 0;
   end record;

   package Block_Vectors is new Ada.Containers.Vectors
      (Index_Type => Positive,
         Element_type => Block);

   Blocks : Block_Vectors.Vector;
   Genesis_Block : Block := (
      Timestamp => 0,
      Last_Hash => To_Unbounded_String ("GENESIS_LAST_HASH"),
      Hash => To_Unbounded_String ("GENESIS_HASH"),
      Data => To_Unbounded_String ("GENESIS"),
      Difficulty => 1,
      Nonce => 1,
      Number => 0
   );

   procedure Block_Pretty_Print
      (B : Block) is
      Msg : Unbounded_String := To_Unbounded_String ("");
   begin
      Msg := Msg & "Block Info #";
      Msg := Msg & Integer'Image (B.Number);
      Msg := Msg & ASCII.LF & "timestamp: "; 
      Msg := Msg & Long_Integer'Image (B.Timestamp);
      Msg := Msg & ASCII.LF & "Last Hash: ";
      Msg := Msg & B.Last_Hash ;
      Msg := Msg & ASCII.LF & "Hash: ";
      Msg := Msg & B.Hash;
      Msg := Msg & ASCII.LF & "Data: ";
      Msg := Msg & B.Data;
      Msg := Msg & ASCII.LF & "Difficulty: ";
      Msg := Msg & Integer'Image (B.Difficulty);
      Msg := Msg & ASCII.LF & "Nonce: ";
      Msg := Msg & Integer'Image (B.Nonce);
      Put_Line (To_String (Msg));
   end Block_Pretty_Print;

   function Block_Hex_To_Binary
      (Hex: String) return String is 
      package My_Map_Type is new Ada.Containers.Indefinite_Ordered_Maps
         (Key_Type => Character,
            Element_Type => String);
      My_Map : My_Map_Type.Map;
      BS : Unbounded_String := To_Unbounded_String ("");
   begin
      My_Map.Insert ('0', "0000");
      My_Map.Insert ('1', "0001");
      My_Map.Insert ('2', "0010");
      My_Map.Insert ('3', "0011");
      My_Map.Insert ('4', "0100");
      My_Map.Insert ('5', "0101");
      My_Map.Insert ('6', "0110");
      My_Map.Insert ('7', "0111");
      My_Map.Insert ('8', "1000");
      My_Map.Insert ('9', "1001");
      My_Map.Insert ('a', "1010");
      My_Map.Insert ('b', "1011");
      My_Map.Insert ('c', "1100");
      My_Map.Insert ('d', "1101");
      My_Map.Insert ('e', "1110");
      My_Map.Insert ('f', "1111");

      For I in Hex'Range loop
         Append (BS, My_Map.Element (Hex (I)));
      end loop;

      return To_String (BS);
   end Block_Hex_To_Binary;

   function Block_Crypto_Hash
      (TS : Long_Integer;
       LH: String;
       D: String;
       DI: Integer;
      N: Integer) return String is 
       
      Data_For_Hash : Unbounded_String := To_Unbounded_String ("");
   begin
      Data_For_Hash := Data_For_Hash & Long_Integer'Image (TS) & LH & D & Integer'Image (N);
      return GNAT.SHA256.Digest ( To_String (Data_For_Hash));
      --  Result_Hex := To_Unbounded_String (GNAT.SHA256.Digest (Data_For_Hash));
      --  return To_String (Result_Hex);
   end Block_Crypto_Hash;

   function Block_Adjust_Difficulty
      (LB : Block;
         NT : Long_Integer) return Integer is 
      Mine_Rate : Long_Integer := 4;
      Time_Diff : Long_Integer := 0;
   begin
      Time_Diff := NT - Long_Integer (LB.Timestamp);
      if Time_Diff < Mine_Rate then
         return LB.Difficulty + 1;
      end if;
      if LB.Difficulty - 1 > 1 then
         return LB.Difficulty - 1;
      else
         return 1;
      end if;
   end Block_Adjust_Difficulty;

   function Mine_Block
      (LB: Block;
         D: String) return Block is 
      Last_Hash : constant String := To_String (LB.Hash);
      Nonce : Integer := 0;
      Difficulty : Integer := 0;
      Block_Hash : Unbounded_String;
      Binary : Unbounded_String := To_Unbounded_String ("");
      Time_Stamp : Long_Integer;
      Epoch : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
      Binary_String : Unbounded_String;
      Is_Proofed : Boolean := true;
      Times_Looped : Integer := 0;
   begin
      loop
         Is_Proofed := True;
         Binary_String := To_Unbounded_String ("");

         --  Times_Looped := Times_Looped + 1;
         --  Put_Line (Integer'Image (Times_Looped));
         --  if Times_Looped >= 100 then
            --  Is_Proofed := True;
            --  goto ProofEnd;
         --  end if;
         Is_Proofed := true;
         Time_Stamp := Long_Integer (Ada.Calendar."-" (Ada.Calendar.Clock, Epoch));
         Difficulty := Block_Adjust_Difficulty (LB, Time_Stamp);
         Block_Hash := To_Unbounded_String (Block_Crypto_Hash (Time_Stamp, Last_Hash, D, Difficulty, Nonce));
         Binary := To_Unbounded_String (Block_Hex_To_Binary (To_String (Block_Hash)));

      --  For I in Hex'Range loop
      --     Append (BS, My_Map.Element (Hex (I)));
      --  end loop;

         for I in 1..Difficulty loop
            Append (Binary_String, '0');
         end loop;

         --  check proof of work
         if Length (Binary) < Length (Binary_String) then
            Is_Proofed := False;
            goto ProofEnd;
         end if;

         For I in 1..Length (Binary_String) loop
            if Element (Binary, I) /= Element (Binary_String, I) then
               Is_Proofed := False;
               goto ProofEnd;
            end if;
         end loop;

         <<ProofEnd>>         
         if Is_Proofed then
            return (
               Timestamp => Time_Stamp,
               Last_Hash => To_Unbounded_String (Last_Hash),
               Hash => Block_Hash, 
               Data => To_Unbounded_String (D),
               Difficulty => Difficulty,
               Nonce => Nonce, 
               Number => LB.Number + 1
            );
         end if;

         Nonce := Nonce + 1;
      end loop;
   end Mine_Block;

   function Is_Valid_Block
      (LB: Block;
      NB: Block) return Boolean is
      --  Binary_String : Unbounded_String;
      --  Binary_Hash : Unbounded_String;
      Recon_Hash : Unbounded_String;
      Difficulty : Integer := 0;
   begin
      if LB.Hash /= NB.Last_Hash then
         return False;
      end if;

      Difficulty := abs LB.Difficulty - NB.Difficulty;
      if Difficulty > 1 then
         return False;
      end if;

--      if recon_hash != block.hash {
--          return false;
--      }

      Recon_Hash := To_Unbounded_String (Block_Crypto_Hash (
         NB.Timestamp,
         To_String (NB.Last_Hash),
         To_String (NB.Data),
         NB.Difficulty,
         NB.Nonce
      ));

      if Recon_Hash /= NB.Hash then
         return False;
      end if;

      if NB.Number /= LB.Number + 1 then
         return False;
      end if;

      return True;
   end Is_Valid_Block;

   procedure Add_Block 
      (D: String) is
      B : Block;
   begin
      B := Mine_Block (Blocks.Last_Element, D);
      Blocks.Append (B);
   end Add_Block;

   function Validate_Chain
      (C: Block_Vectors.Vector) return Boolean is
      Index : Integer := 0;
      LB : Block;
      Is_Valid : Boolean;
   begin
      if C.Element (1) /= Genesis_Block then
         return False;
      end if;

      for I in 1..C.Length loop
         LB := C.Element (Integer (I));
         Index := LB.Number - 1;
         if Index /= -1 then
            LB := C.Element (Index);

            Is_Valid := Is_Valid_Block (LB, C.Element (Integer (I)));

            if Is_Valid = False then
               return False;
            end if;
         end if;
      end loop;

      return True;
   end Validate_Chain;

begin
   --  Add genesis block
   Blocks.Append (Genesis_Block);

   loop
      Add_Block ("Some data");
      Block_Pretty_Print (Blocks.Last_Element);
      Put_Line (" ==================== ");
   end loop;
end Chain;