import { useRef, useState } from 'react';
import { Sun, Moon, Monitor, Check, Bell, User, Lock, FileText, Info, Upload, Trash2, Loader2 } from 'lucide-react';
import type { Profile, ThemeMode } from '@/types';
import { supabase } from '@/lib/supabase';

const avatarColors = ['#2777b8', '#0c8f80', '#7b5e9d', '#b86934', '#a44865', '#2d7a4f', '#c4632e', '#5a4a9e'];
const MAX_FILE_SIZE = 5 * 1024 * 1024;

export function SettingsView({ profile, theme, setTheme, onSaved }: { profile: Profile; theme: ThemeMode; setTheme: (m: ThemeMode) => void; onSaved: (p: Profile) => void }) {
  const [tab, setTab] = useState<'account' | 'appearance' | 'notifications' | 'privacy' | 'terms' | 'about'>('account');
  const [displayName, setDisplayName] = useState(profile.display_name);
  const [bio, setBio] = useState(profile.bio || '');
  const [avatarColor, setAvatarColor] = useState(profile.avatar_color);
  const [avatarUrl, setAvatarUrl] = useState(profile.avatar_url);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [saveError, setSaveError] = useState('');
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState('');
  const [removing, setRemoving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const save = async () => {
    setSaving(true); setSaveError('');
    const { error } = await supabase
      .from('profiles')
      .update({ display_name: displayName, bio, avatar_color: avatarColor, updated_at: new Date().toISOString() })
      .eq('id', profile.id);
    if (error) {
      const msg = error.message.toLowerCase();
      if (msg.includes('row level') || msg.includes('policy')) setSaveError('You are not authorized to update this profile.');
      else setSaveError('Profile could not be saved. Please try again.');
      console.error('Profile save error:', error.message);
    } else {
      onSaved({ ...profile, display_name: displayName, bio, avatar_color: avatarColor, avatar_url: avatarUrl });
      setSaved(true); setTimeout(() => setSaved(false), 2000);
    }
    setSaving(false);
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadError('');
    if (!file.type.startsWith('image/')) { setUploadError('Only image files are supported.'); return; }
    if (file.size > MAX_FILE_SIZE) { setUploadError('Image is too large. Maximum size is 5 MB.'); return; }
    setUploading(true);
    const ext = file.name.split('.').pop() || 'jpg';
    const fileName = `${profile.id}/${crypto.randomUUID()}.${ext}`;
    const { error: upErr } = await supabase.storage.from('avatars').upload(fileName, file, { contentType: file.type, upsert: false });
    if (upErr) {
      setUploadError('Upload failed. Please try again.');
      console.error('Avatar upload error:', upErr.message);
      setUploading(false);
      return;
    }
    const { data: pub } = supabase.storage.from('avatars').getPublicUrl(fileName);
    const publicUrl = pub.publicUrl;
    // Delete old avatar if one existed
    if (avatarUrl) {
      const oldPath = avatarUrl.split('/avatars/')[1];
      if (oldPath && oldPath.startsWith(profile.id + '/')) {
        await supabase.storage.from('avatars').remove([oldPath]);
      }
    }
    const { error: dbErr } = await supabase.from('profiles').update({ avatar_url: publicUrl, updated_at: new Date().toISOString() }).eq('id', profile.id);
    setUploading(false);
    if (dbErr) {
      setUploadError('Could not save avatar to your profile.');
      console.error('Avatar DB update error:', dbErr.message);
      return;
    }
    setAvatarUrl(publicUrl);
    onSaved({ ...profile, display_name: displayName, bio, avatar_color: avatarColor, avatar_url: publicUrl });
    if (fileRef.current) fileRef.current.value = '';
  };

  const removeAvatar = async () => {
    setRemoving(true); setUploadError('');
    if (avatarUrl) {
      const oldPath = avatarUrl.split('/avatars/')[1];
      if (oldPath && oldPath.startsWith(profile.id + '/')) {
        await supabase.storage.from('avatars').remove([oldPath]);
      }
    }
    const { error } = await supabase.from('profiles').update({ avatar_url: null, updated_at: new Date().toISOString() }).eq('id', profile.id);
    setRemoving(false);
    if (error) { setUploadError('Could not remove avatar. Please try again.'); return; }
    setAvatarUrl(null);
    onSaved({ ...profile, display_name: displayName, bio, avatar_color: avatarColor, avatar_url: null });
  };

  const tabs = [
    ['account', 'Account', <User size={16} key="a" />],
    ['appearance', 'Appearance', <Sun size={16} key="ap" />],
    ['notifications', 'Notifications', <Bell size={16} key="n" />],
    ['privacy', 'Privacy', <Lock size={16} key="p" />],
    ['terms', 'Terms', <FileText size={16} key="t" />],
    ['about', 'About', <Info size={16} key="ab" />],
  ] as const;

  const initials = (displayName || profile.username || '?').slice(0, 2).toUpperCase();

  return (
    <div className="flex-1 overflow-y-auto px-5 py-8 sm:px-8 lg:px-12 pb-24 lg:pb-8">
      <div className="max-w-4xl mx-auto">
        <h2 className="font-display text-3xl font-bold text-white mb-8">Settings</h2>
        <div className="grid sm:grid-cols-[200px_1fr] gap-6">
          <nav className="space-y-1">
            {tabs.map(([value, label, icon]) => (
              <button key={value} onClick={() => setTab(value as typeof tab)} className={`w-full flex items-center gap-3 rounded-xl px-4 py-2.5 text-sm transition ${tab === value ? 'bg-[#213c5a] text-white' : 'text-[#849bb4] hover:bg-[#192d45]'}`}>
                {icon} {label}
              </button>
            ))}
          </nav>

          <div className="min-w-0">
            {tab === 'account' && (
              <div className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-6">
                <h3 className="font-display font-bold text-white mb-5">Account</h3>
                <div className="space-y-5">
                  <div>
                    <label className="text-xs font-semibold uppercase tracking-wider text-[#7f99b5]">Profile picture</label>
                    <div className="mt-3 flex items-center gap-4">
                      <div className="h-16 w-16 rounded-2xl flex items-center justify-center font-display font-bold text-white shadow-lg overflow-hidden shrink-0" style={{ background: avatarColor }}>
                        {avatarUrl ? <img src={avatarUrl} alt="" className="h-full w-full object-cover" /> : initials}
                      </div>
                      <div className="flex flex-col gap-2">
                        <input ref={fileRef} type="file" accept="image/*" onChange={handleFileSelect} className="hidden" />
                        <button onClick={() => fileRef.current?.click()} disabled={uploading || removing} className="flex items-center gap-2 rounded-xl border border-[#30455f] bg-[#132439] px-4 py-2 text-sm text-[#c2d2e1] hover:border-[#4ca8ef] disabled:opacity-50">
                          {uploading ? <><Loader2 size={15} className="animate-spin" /> Uploading…</> : <><Upload size={15} /> Upload image</>}
                        </button>
                        {avatarUrl && <button onClick={removeAvatar} disabled={removing || uploading} className="flex items-center gap-2 rounded-xl border border-[#4a2233] px-4 py-2 text-sm text-[#ffadbd] hover:bg-[#3c2230] disabled:opacity-50">
                          {removing ? <><Loader2 size={15} className="animate-spin" /> Removing…</> : <><Trash2 size={15} /> Remove</>}
                        </button>}
                      </div>
                    </div>
                    {uploadError && <div className="mt-2 text-xs text-[#ffb8c6]">{uploadError}</div>}
                    <p className="mt-2 text-xs text-[#637b96]">JPG, PNG, or GIF up to 5 MB.</p>
                  </div>
                  <div>
                    <label className="text-xs font-semibold uppercase tracking-wider text-[#7f99b5]">Display name</label>
                    <input value={displayName} onChange={e => setDisplayName(e.target.value)} className="mt-2 w-full rounded-xl border border-[#30455f] bg-[#101d2e] px-4 py-3 text-white outline-none focus:border-[#4ca8ef]" />
                  </div>
                  <div>
                    <label className="text-xs font-semibold uppercase tracking-wider text-[#7f99b5]">Username</label>
                    <div className="mt-2 w-full rounded-xl border border-[#30455f] bg-[#0c1828] px-4 py-3 text-[#7189a3]">@{profile.username}</div>
                    <p className="mt-1 text-xs text-[#637b96]">Your username cannot be changed.</p>
                  </div>
                  <div>
                    <label className="text-xs font-semibold uppercase tracking-wider text-[#7f99b5]">Bio</label>
                    <textarea value={bio} onChange={e => setBio(e.target.value)} rows={3} placeholder="Tell your school community a bit about you" className="mt-2 w-full rounded-xl border border-[#30455f] bg-[#101d2e] px-4 py-3 text-white outline-none focus:border-[#4ca8ef] resize-none" />
                  </div>
                  <div>
                    <label className="text-xs font-semibold uppercase tracking-wider text-[#7f99b5]">Avatar color</label>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {avatarColors.map(c => (
                        <button key={c} onClick={() => setAvatarColor(c)} className={`h-9 w-9 rounded-xl transition ${avatarColor === c ? 'ring-2 ring-white ring-offset-2 ring-offset-[#101d2e]' : ''}`} style={{ background: c }}>
                          {avatarColor === c && <Check size={16} className="text-white mx-auto" />}
                        </button>
                      ))}
                    </div>
                  </div>
                  {saveError && <div className="rounded-xl border border-[#7e3b4c] bg-[#3a1d2a] px-4 py-3 text-sm text-[#ffb8c6]">{saveError}</div>}
                  <button onClick={save} disabled={saving} className="rounded-xl bg-[#247bbb] px-5 py-2.5 text-sm font-semibold text-white hover:bg-[#2e8bcf] disabled:opacity-50">
                    {saved ? 'Saved!' : saving ? 'Saving...' : 'Save changes'}
                  </button>
                </div>
              </div>
            )}

            {tab === 'appearance' && (
              <div className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-6">
                <h3 className="font-display font-bold text-white mb-5">Appearance</h3>
                <div className="space-y-3">
                  {([['dark', 'Dark', <Moon size={18} key="d" />], ['light', 'Light', <Sun size={18} key="l" />], ['system', 'System', <Monitor size={18} key="s" />]] as const).map(([mode, label, icon]) => (
                    <button key={mode} onClick={() => setTheme(mode)} className={`w-full flex items-center gap-3 rounded-xl border p-4 transition ${theme === mode ? 'border-[#4ca8ef] bg-[#17304a]' : 'border-[#29435d] bg-[#13263b] hover:border-[#3b6286]'}`}>
                      <div className={`h-9 w-9 rounded-xl flex items-center justify-center ${theme === mode ? 'bg-[#247bbb] text-white' : 'bg-[#1d3045] text-[#718da7]'}`}>{icon}</div>
                      <span className={`text-sm font-semibold ${theme === mode ? 'text-white' : 'text-[#849bb4]'}`}>{label}</span>
                      {theme === mode && <Check size={18} className="ml-auto text-[#61d3ad]" />}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {tab === 'notifications' && (
              <div className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-6">
                <h3 className="font-display font-bold text-white mb-2">Notifications</h3>
                <p className="text-sm text-[#718ba6] mb-5">These preferences are saved on this device only. Server-side notification settings will be available in a future release.</p>
                <div className="space-y-3">
                  {[['Friend requests', true], ['Direct messages', true], ['Mentions and replies', true], ['Announcements', true], ['Report updates', false]].map(([label, defaultOn]) => (
                    <label key={label as string} className="flex items-center justify-between rounded-xl border border-[#29435d] bg-[#13263b] p-4 cursor-pointer">
                      <span className="text-sm text-[#dbe9f5]">{label as string}</span>
                      <input type="checkbox" defaultChecked={defaultOn as boolean} className="h-5 w-5 rounded accent-[#2e8bcf]" />
                    </label>
                  ))}
                </div>
              </div>
            )}

            {tab === 'privacy' && (
              <div className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-6">
                <h3 className="font-display font-bold text-white mb-2">Privacy</h3>
                <p className="text-sm text-[#718ba6] mb-5">Your school controls class access and direct message permissions.</p>
                <div className="space-y-3 text-sm text-[#a0b4c7] leading-6">
                  <p>Your display name, username, and messages are visible to authorized members of your school community.</p>
                  <p>Direct messages are only visible to you and the other participant.</p>
                  <p>Your email address is never shown as your public identifier.</p>
                  <p>Teachers and administrators can access messages for moderation and safety purposes.</p>
                </div>
              </div>
            )}

            {tab === 'terms' && (
              <div className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-6">
                <h3 className="font-display font-bold text-white mb-2">Terms & Conditions</h3>
                <p className="text-sm text-[#718ba6] mb-4">This is a placeholder version. Your school must replace it with officially approved wording.</p>
                <div className="rounded-xl border border-[#263a54] bg-[#0c1828] p-4 text-sm leading-6 text-[#91a7c2]">
                  SchoolChat Beta Terms & Conditions v1.0 — See the full terms on the Terms page.
                </div>
              </div>
            )}

            {tab === 'about' && (
              <div className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-6">
                <h3 className="font-display font-bold text-white mb-2">About SchoolChat</h3>
                <p className="text-sm text-[#a0b4c7] leading-7">SchoolChat is currently in beta and is being tested and improved with the school community.</p>
                <div className="mt-4 flex items-center gap-2 text-xs text-[#637b96]">
                  <span className="rounded-full bg-[#1d547c] px-2 py-0.5 text-[#89d2ff] font-bold">BETA</span>
                  Version 1.0.0
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
