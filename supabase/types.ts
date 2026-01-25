export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      project_options: {
        Row: {
          created_at: string
          description: string | null
          id: string
          is_archived: boolean
          is_default: boolean
          model_url: string | null
          name: string
          project_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_archived?: boolean
          is_default?: boolean
          model_url?: string | null
          name: string
          project_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_archived?: boolean
          is_default?: boolean
          model_url?: string | null
          name?: string
          project_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "project_options_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_options_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects_full"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          created_at: string
          description: string | null
          id: string
          models_context: string[] | null
          models_heatmap: string | null
          name: string
          spatial_lens_url: string | null
          spatial_simulation_url: string | null
          status: Database["public"]["Enums"]["project_status"]
          updated_at: string | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          models_context?: string[] | null
          models_heatmap?: string | null
          name: string
          spatial_lens_url?: string | null
          spatial_simulation_url?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string | null
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          models_context?: string[] | null
          models_heatmap?: string | null
          name?: string
          spatial_lens_url?: string | null
          spatial_simulation_url?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string | null
        }
        Relationships: []
      }
      records: {
        Row: {
          created_at: string
          device_type: string | null
          id: string
          is_archived: boolean
          length_ms: number | null
          option_id: string
          project_id: string
          raw_url: string | null
          record_url: string
          scenario_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string
          device_type?: string | null
          id?: string
          is_archived?: boolean
          length_ms?: number | null
          option_id: string
          project_id: string
          raw_url?: string | null
          record_url: string
          scenario_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string
          device_type?: string | null
          id?: string
          is_archived?: boolean
          length_ms?: number | null
          option_id?: string
          project_id?: string
          raw_url?: string | null
          record_url?: string
          scenario_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "records_option_id_fkey"
            columns: ["option_id"]
            isOneToOne: false
            referencedRelation: "project_options"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "records_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "records_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "records_scenario_id_fkey"
            columns: ["scenario_id"]
            isOneToOne: false
            referencedRelation: "scenarios"
            referencedColumns: ["id"]
          },
        ]
      }
      scenarios: {
        Row: {
          created_at: string
          description: string | null
          destination_coordinates: Json
          id: string
          is_archived: boolean
          name: string
          objective: string
          option_id: string
          start_coordinates: Json
          updated_at: string | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          destination_coordinates?: Json
          id?: string
          is_archived?: boolean
          name: string
          objective: string
          option_id: string
          start_coordinates?: Json
          updated_at?: string | null
        }
        Update: {
          created_at?: string
          description?: string | null
          destination_coordinates?: Json
          id?: string
          is_archived?: boolean
          name?: string
          objective?: string
          option_id?: string
          start_coordinates?: Json
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "scenarios_option_id_fkey"
            columns: ["option_id"]
            isOneToOne: false
            referencedRelation: "project_options"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      projects_full: {
        Row: {
          created_at: string | null
          description: string | null
          id: string | null
          models_context: string[] | null
          models_heatmap: string | null
          name: string | null
          options: Json | null
          spatial_lens_url: string | null
          spatial_simulation_url: string | null
          status: Database["public"]["Enums"]["project_status"] | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string | null
          models_context?: string[] | null
          models_heatmap?: string | null
          name?: string | null
          options?: never
          spatial_lens_url?: string | null
          spatial_simulation_url?: string | null
          status?: Database["public"]["Enums"]["project_status"] | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string | null
          models_context?: string[] | null
          models_heatmap?: string | null
          name?: string | null
          options?: never
          spatial_lens_url?: string | null
          spatial_simulation_url?: string | null
          status?: Database["public"]["Enums"]["project_status"] | null
          updated_at?: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      get_project_full: { Args: { p_project_id: string }; Returns: Json }
    }
    Enums: {
      project_status: "development" | "released" | "archived"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      project_status: ["development", "released", "archived"],
    },
  },
} as const
