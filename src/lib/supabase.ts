import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
export const supabase = url && anonKey ? createClient(url, anonKey) : null;
export const isConfigured = Boolean(supabase);

export type Activity = { id: string; activity_date: string; activity_type: string; area_name: string; notes: string; status: string };
export async function fetchActivities(): Promise<Activity[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.from('daily_activities').select('id,activity_date,activity_type,area_name,notes,status').order('activity_date', { ascending: false }).limit(50);
  if (error) throw error;
  return (data ?? []) as Activity[];
}
export async function saveActivity(activity: Omit<Activity, 'id'>) {
  if (!supabase) throw new Error('Connect Supabase to save records.');
  const { error } = await supabase.from('daily_activities').insert(activity);
  if (error) throw error;
}
