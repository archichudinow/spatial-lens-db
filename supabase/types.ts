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
          model_file_size: number | null
          model_uploaded_at: string | null
          model_url: string | null
          name: string
          project_id: string
          updated_at: string | null
          upload_error: string | null
          upload_retry_count: number | null
          upload_status: Database["public"]["Enums"]["upload_status"] | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_archived?: boolean
          is_default?: boolean
          model_file_size?: number | null
          model_uploaded_at?: string | null
          model_url?: string | null
          name: string
          project_id: string
          updated_at?: string | null
          upload_error?: string | null
          upload_retry_count?: number | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_archived?: boolean
          is_default?: boolean
          model_file_size?: number | null
          model_uploaded_at?: string | null
          model_url?: string | null
          name?: string
          project_id?: string
          updated_at?: string | null
          upload_error?: string | null
          upload_retry_count?: number | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
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
          required_files: Json | null
          spatial_lens_url: string | null
          spatial_simulation_url: string | null
          status: Database["public"]["Enums"]["project_status"]
          updated_at: string | null
          upload_error: string | null
          upload_retry_count: number | null
          upload_status: Database["public"]["Enums"]["upload_status"] | null
          uploaded_files: Json | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          models_context?: string[] | null
          models_heatmap?: string | null
          name: string
          required_files?: Json | null
          spatial_lens_url?: string | null
          spatial_simulation_url?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string | null
          upload_error?: string | null
          upload_retry_count?: number | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
          uploaded_files?: Json | null
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          models_context?: string[] | null
          models_heatmap?: string | null
          name?: string
          required_files?: Json | null
          spatial_lens_url?: string | null
          spatial_simulation_url?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string | null
          upload_error?: string | null
          upload_retry_count?: number | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
          uploaded_files?: Json | null
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
          raw_file_size: number | null
          raw_uploaded_at: string | null
          raw_url: string | null
          record_file_size: number | null
          record_uploaded_at: string | null
          record_url: string | null
          scenario_id: string
          updated_at: string | null
          upload_error: string | null
          upload_retry_count: number | null
          upload_status: Database["public"]["Enums"]["upload_status"] | null
        }
        Insert: {
          created_at?: string
          device_type?: string | null
          id?: string
          is_archived?: boolean
          length_ms?: number | null
          option_id: string
          project_id: string
          raw_file_size?: number | null
          raw_uploaded_at?: string | null
          raw_url?: string | null
          record_file_size?: number | null
          record_uploaded_at?: string | null
          record_url?: string | null
          scenario_id: string
          updated_at?: string | null
          upload_error?: string | null
          upload_retry_count?: number | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
        }
        Update: {
          created_at?: string
          device_type?: string | null
          id?: string
          is_archived?: boolean
          length_ms?: number | null
          option_id?: string
          project_id?: string
          raw_file_size?: number | null
          raw_uploaded_at?: string | null
          raw_url?: string | null
          record_file_size?: number | null
          record_uploaded_at?: string | null
          record_url?: string | null
          scenario_id?: string
          updated_at?: string | null
          upload_error?: string | null
          upload_retry_count?: number | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
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
      upload_files: {
        Row: {
          created_at: string
          entity_id: string
          entity_type: string
          file_path: string
          file_size: number | null
          file_type: string
          id: string
          is_required: boolean | null
          metadata: Json | null
          mime_type: string | null
          updated_at: string | null
          upload_status: Database["public"]["Enums"]["upload_status"] | null
          uploaded_at: string | null
          verified_at: string | null
        }
        Insert: {
          created_at?: string
          entity_id: string
          entity_type: string
          file_path: string
          file_size?: number | null
          file_type: string
          id?: string
          is_required?: boolean | null
          metadata?: Json | null
          mime_type?: string | null
          updated_at?: string | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
          uploaded_at?: string | null
          verified_at?: string | null
        }
        Update: {
          created_at?: string
          entity_id?: string
          entity_type?: string
          file_path?: string
          file_size?: number | null
          file_type?: string
          id?: string
          is_required?: boolean | null
          metadata?: Json | null
          mime_type?: string | null
          updated_at?: string | null
          upload_status?: Database["public"]["Enums"]["upload_status"] | null
          uploaded_at?: string | null
          verified_at?: string | null
        }
        Relationships: []
      }
      upload_sessions: {
        Row: {
          chunk_size: number | null
          completed_at: string | null
          created_at: string
          entity_id: string
          entity_type: string
          error_message: string | null
          expires_at: string
          file_name: string
          file_type: string
          final_path: string
          id: string
          mime_type: string | null
          session_status: string | null
          total_chunks: number
          total_size: number
          updated_at: string | null
          uploaded_chunks: number[] | null
        }
        Insert: {
          chunk_size?: number | null
          completed_at?: string | null
          created_at?: string
          entity_id: string
          entity_type: string
          error_message?: string | null
          expires_at?: string
          file_name: string
          file_type: string
          final_path: string
          id?: string
          mime_type?: string | null
          session_status?: string | null
          total_chunks: number
          total_size: number
          updated_at?: string | null
          uploaded_chunks?: number[] | null
        }
        Update: {
          chunk_size?: number | null
          completed_at?: string | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          error_message?: string | null
          expires_at?: string
          file_name?: string
          file_type?: string
          final_path?: string
          id?: string
          mime_type?: string | null
          session_status?: string | null
          total_chunks?: number
          total_size?: number
          updated_at?: string | null
          uploaded_chunks?: number[] | null
        }
        Relationships: []
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
      cleanup_expired_upload_sessions: { Args: never; Returns: Json }
      finalize_option: { Args: { option_id: string }; Returns: Json }
      finalize_record: { Args: { record_id: string }; Returns: Json }
      find_abandoned_uploads: {
        Args: { threshold_hours?: number }
        Returns: {
          completed_files: number
          created_at: string
          entity_id: string
          entity_type: string
          hours_old: number
          total_files: number
          upload_status: Database["public"]["Enums"]["upload_status"]
        }[]
      }
      generate_option_model_path: {
        Args: {
          p_option_id: string
          p_project_id: string
          p_timestamp?: number
        }
        Returns: string
      }
      generate_project_other_path: {
        Args: {
          p_file_type: string
          p_project_id: string
          p_timestamp?: number
        }
        Returns: string
      }
      generate_record_glb_path: {
        Args: {
          p_option_id: string
          p_project_id: string
          p_scenario_id: string
          p_timestamp?: number
        }
        Returns: string
      }
      generate_record_raw_path: {
        Args: {
          p_extension?: string
          p_option_id: string
          p_project_id: string
          p_scenario_id: string
          p_timestamp?: number
        }
        Returns: string
      }
      get_project_folder_name: { Args: { project_id: string }; Returns: string }
      get_project_full: { Args: { p_project_id: string }; Returns: Json }
      get_project_storage_path: {
        Args: {
          p_file_type: string
          p_option_id?: string
          p_project_id: string
          p_record_id?: string
          p_scenario_id?: string
        }
        Returns: string
      }
      get_upload_session_status: {
        Args: { p_session_id: string }
        Returns: Json
      }
      mark_chunk_completed: {
        Args: { p_chunk_index: number; p_session_id: string }
        Returns: Json
      }
      reset_option_for_reupload: {
        Args: { p_option_id: string }
        Returns: Json
      }
      reset_record_for_reupload: {
        Args: { p_record_id: string }
        Returns: Json
      }
    }
    Enums: {
      project_status: "development" | "released" | "archived"
      upload_status: "draft" | "uploading" | "completed" | "failed"
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
      upload_status: ["draft", "uploading", "completed", "failed"],
    },
  },
} as const
