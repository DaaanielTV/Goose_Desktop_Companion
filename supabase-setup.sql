-- Supabase Self-Hosted Database Setup
-- Desktop Goose Cloud Sync

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (anonymous or authenticated)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT UNIQUE NOT NULL,
    device_name TEXT,
    email TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE
);

-- Sync profiles (devices)
CREATE TABLE IF NOT EXISTS sync_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_type TEXT DEFAULT 'desktop',
    last_sync TIMESTAMP WITH TIME ZONE,
    sync_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- Main sync data table
CREATE TABLE IF NOT EXISTS sync_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    data_type TEXT NOT NULL,
    data JSONB,
    local_modified TIMESTAMP WITH TIME ZONE NOT NULL,
    server_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT false,
    version INTEGER DEFAULT 1,
    UNIQUE(user_id, data_type, device_id)
);

-- Sync history/audit log
CREATE TABLE IF NOT EXISTS sync_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    data_type TEXT,
    operation TEXT NOT NULL,
    status TEXT NOT NULL,
    records_count INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sync_data_user_id ON sync_data(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_data_device_id ON sync_data(device_id);
CREATE INDEX IF NOT EXISTS idx_sync_data_type ON sync_data(data_type);
CREATE INDEX IF NOT EXISTS idx_sync_data_user_type ON sync_data(user_id, data_type);
CREATE INDEX IF NOT EXISTS idx_sync_history_user_id ON sync_history(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_history_created ON sync_history(created_at);

-- Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id OR device_id = current_setting('app.settings.device_id', true));

CREATE POLICY "Users can insert own data" ON users
    FOR INSERT WITH CHECK (auth.uid() = id OR true);

CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id OR device_id = current_setting('app.settings.device_id', true));

-- RLS Policies for sync_profiles
CREATE POLICY "Users can view own profiles" ON sync_profiles
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert own profiles" ON sync_profiles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own profiles" ON sync_profiles
    FOR UPDATE USING (true);

-- RLS Policies for sync_data
CREATE POLICY "Users can view own sync data" ON sync_data
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert own sync data" ON sync_data
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own sync data" ON sync_data
    FOR UPDATE USING (true);

CREATE POLICY "Users can delete own sync data" ON sync_data
    FOR DELETE USING (true);

-- RLS Policies for sync_history
CREATE POLICY "Users can view own history" ON sync_history
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert own history" ON sync_history
    FOR INSERT WITH CHECK (true);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sync_profiles_updated_at BEFORE UPDATE ON sync_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sync_data_updated_at BEFORE UPDATE ON sync_data
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to get latest sync data for a user
CREATE OR REPLACE FUNCTION get_latest_sync_data(p_user_id UUID, p_data_type TEXT)
RETURNS TABLE(
    id UUID,
    data JSONB,
    local_modified TIMESTAMP WITH TIME ZONE,
    server_modified TIMESTAMP WITH TIME ZONE,
    device_id TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sd.id,
        sd.data,
        sd.local_modified,
        sd.server_modified,
        sd.device_id
    FROM sync_data sd
    WHERE sd.user_id = p_user_id 
      AND sd.data_type = p_data_type
      AND sd.is_deleted = false
    ORDER BY sd.local_modified DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to upsert sync data
CREATE OR REPLACE FUNCTION upsert_sync_data(
    p_user_id UUID,
    p_device_id TEXT,
    p_data_type TEXT,
    p_data JSONB,
    p_local_modified TIMESTAMP WITH TIME ZONE
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
    v_existing RECORD;
BEGIN
    -- Check if record exists
    SELECT id, version INTO v_existing
    FROM sync_data
    WHERE user_id = p_user_id 
      AND data_type = p_data_type
      AND device_id = p_device_id
      AND is_deleted = false
    ORDER BY version DESC
    LIMIT 1;
    
    IF v_existing IS NOT NULL THEN
        -- Update existing record
        UPDATE sync_data
        SET data = p_data,
            local_modified = p_local_modified,
            server_modified = NOW(),
            version = version + 1,
            updated_at = NOW()
        WHERE id = v_existing.id
        RETURNING id INTO v_id;
    ELSE
        -- Insert new record
        INSERT INTO sync_data (user_id, device_id, data_type, data, local_modified)
        VALUES (p_user_id, p_device_id, p_data_type, p_data, p_local_modified)
        RETURNING id INTO v_id;
    END IF;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Insert or update user function
CREATE OR REPLACE FUNCTION get_or_create_user(p_device_id TEXT, p_device_name TEXT DEFAULT NULL)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id FROM users WHERE device_id = p_device_id;
    
    IF v_user_id IS NULL THEN
        INSERT INTO users (device_id, device_name, last_login_at)
        VALUES (p_device_id, p_device_name, NOW())
        RETURNING id INTO v_user_id;
    ELSE
        UPDATE users SET last_login_at = NOW() WHERE id = v_user_id;
    END IF;
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (for service role)
GRANT ALL ON users TO service_role;
GRANT ALL ON sync_profiles TO service_role;
GRANT ALL ON sync_data TO service_role;
GRANT ALL ON sync_history TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- =============================================
-- Analytics & Reporting Tables
-- =============================================

-- Aggregierte Analytics (tägliche Zusammenfassungen)
CREATE TABLE IF NOT EXISTS analytics_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    date DATE NOT NULL,
    metric_name TEXT NOT NULL,
    metric_category TEXT NOT NULL,      -- 'productivity', 'habits', 'sync', 'telemetry'
    value JSONB NOT NULL,
    computed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_id, date, metric_name, metric_category)
);

-- Reports (periodisch generiert)
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    report_type TEXT NOT NULL,         -- 'weekly_summary', 'habit_analysis', 'productivity_report', 'sync_stats'
    date_range_start DATE NOT NULL,
    date_range_end DATE NOT NULL,
    title TEXT,
    summary JSONB,
    details JSONB,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Goals & Achievements
CREATE TABLE IF NOT EXISTS goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    goal_type TEXT NOT NULL,           -- 'habit_streak', 'focus_time_total', 'notes_count', 'sync_frequency'
    goal_name TEXT,
    target_value DOUBLE PRECISION NOT NULL,
    current_value DOUBLE PRECISION DEFAULT 0,
    unit TEXT,                          -- 'minutes', 'hours', 'count', 'days'
    start_date DATE NOT NULL,
    end_date DATE,
    achieved_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Achievement Badges
CREATE TABLE IF NOT EXISTS achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    achievement_key TEXT NOT NULL,      -- 'first_sync', 'week_streak', 'notes_10', 'focus_100h'
    achievement_name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    progress_current DOUBLE PRECISION DEFAULT 0,
    progress_target DOUBLE PRECISION NOT NULL,
    is_unlocked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, achievement_key)
);

-- Indexes for Analytics
CREATE INDEX IF NOT EXISTS idx_analytics_summaries_user_date ON analytics_summaries(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_summaries_metric ON analytics_summaries(metric_name, metric_category);
CREATE INDEX IF NOT EXISTS idx_reports_user_type ON reports(user_id, report_type);
CREATE INDEX IF NOT EXISTS idx_reports_date ON reports(date_range_start, date_range_end);
CREATE INDEX IF NOT EXISTS idx_goals_user_active ON goals(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_achievements_user ON achievements(user_id, is_unlocked);

-- Enable RLS on Analytics tables
ALTER TABLE analytics_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Analytics
CREATE POLICY "Users can view own analytics" ON analytics_summaries
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert analytics" ON analytics_summaries
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own reports" ON reports
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert reports" ON reports
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own goals" ON goals
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert goals" ON goals
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own achievements" ON achievements
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert achievements" ON achievements
    FOR INSERT WITH CHECK (true);

-- Grant permissions
GRANT ALL ON analytics_summaries TO service_role;
GRANT ALL ON reports TO service_role;
GRANT ALL ON goals TO service_role;
GRANT ALL ON achievements TO service_role;

-- =============================================
-- Analytics Functions
-- =============================================

-- Function: Compute daily analytics summary
CREATE OR REPLACE FUNCTION compute_daily_summary(
    p_user_id UUID,
    p_device_id TEXT,
    p_date DATE
)
RETURNS TABLE(
    metric_name TEXT,
    metric_category TEXT,
    value JSONB
) AS $$
DECLARE
    v_result TABLE(metric_name TEXT, metric_category TEXT, value JSONB);
BEGIN
    -- Calculate habit completion rate
    INSERT INTO analytics_summaries (user_id, device_id, date, metric_name, metric_category, value)
    SELECT 
        p_user_id,
        p_device_id,
        p_date,
        'habit_completion_rate',
        'habits',
        (
            SELECT jsonb_build_object(
                'total_habits', COUNT(*),
                'completed_habits', COUNT(*) FILTER (WHERE completed = true),
                'completion_rate', ROUND(COUNT(*) FILTER (WHERE completed = true)::numeric / NULLIF(COUNT(*), 0)::numeric * 100, 2)
            )
            FROM sync_data
            WHERE user_id = p_user_id 
            AND data_type = 'habits'
            AND device_id = p_device_id
            AND is_deleted = false
        )
        WHERE EXISTS (
            SELECT 1 FROM sync_data 
            WHERE user_id = p_user_id AND data_type = 'habits'
        )
    ON CONFLICT (user_id, device_id, date, metric_name, metric_category) DO UPDATE
    SET value = EXCLUDED.value, computed_at = NOW();

    -- Calculate sync activity
    INSERT INTO analytics_summaries (user_id, device_id, date, metric_name, metric_category, value)
    SELECT 
        p_user_id,
        p_device_id,
        p_date,
        'sync_activity',
        'sync',
        (
            SELECT jsonb_build_object(
                'total_syncs', COUNT(*),
                'successful_syncs', COUNT(*) FILTER (WHERE status = 'success'),
                'failed_syncs', COUNT(*) FILTER (WHERE status = 'error')
            )
            FROM sync_history
            WHERE user_id = p_user_id 
            AND DATE(created_at) = p_date
        )
    ON CONFLICT (user_id, device_id, date, metric_name, metric_category) DO UPDATE
    SET value = EXCLUDED.value, computed_at = NOW();

    RETURN QUERY
    SELECT metric_name, metric_category, value
    FROM analytics_summaries
    WHERE user_id = p_user_id AND device_id = p_device_id AND date = p_date;
END;
$$ LANGUAGE plpgsql;

-- Function: Generate weekly report
CREATE OR REPLACE FUNCTION generate_weekly_report(
    p_user_id UUID,
    p_device_id TEXT,
    p_week_start DATE
)
RETURNS UUID AS $$
DECLARE
    v_report_id UUID;
    v_week_end DATE;
    v_summary JSONB;
    v_details JSONB;
    v_habit_completion JSONB;
    v_sync_stats JSONB;
    v_goal_progress JSONB;
BEGIN
    v_week_end = p_week_start + 6;

    -- Get habit completion for the week
    SELECT jsonb_agg(jsonb_build_object(
        'date', date,
        'metric_name', metric_name,
        'value', value
    )) INTO v_habit_completion
    FROM analytics_summaries
    WHERE user_id = p_user_id 
    AND device_id = p_device_id 
    AND date BETWEEN p_week_start AND v_week_end
    AND metric_category = 'habits';

    -- Get sync stats
    SELECT jsonb_build_object(
        'total_syncs', COUNT(*),
        'successful', COUNT(*) FILTER (WHERE status = 'success'),
        'failed', COUNT(*) FILTER (WHERE status = 'error')
    ) INTO v_sync_stats
    FROM sync_history
    WHERE user_id = p_user_id 
    AND DATE(created_at) BETWEEN p_week_start AND v_week_end;

    -- Get goal progress
    SELECT jsonb_agg(jsonb_build_object(
        'goal_type', goal_type,
        'goal_name', goal_name,
        'current_value', current_value,
        'target_value', target_value,
        'progress_percent', ROUND(current_value / NULLIF(target_value, 0) * 100, 2)
    )) INTO v_goal_progress
    FROM goals
    WHERE user_id = p_user_id 
    AND device_id = p_device_id
    AND is_active = true
    AND start_date <= v_week_end
    AND (end_date IS NULL OR end_date >= p_week_start);

    -- Build summary
    v_summary = jsonb_build_object(
        'habits', v_habit_completion,
        'sync', v_sync_stats,
        'goals', v_goal_progress
    );

    v_details = jsonb_build_object(
        'period_start', p_week_start,
        'period_end', v_week_end,
        'generated_at', NOW()
    );

    -- Insert report
    INSERT INTO reports (user_id, device_id, report_type, date_range_start, date_range_end, title, summary, details)
    VALUES (p_user_id, p_device_id, 'weekly_summary', p_week_start, v_week_end, 
            'Weekly Summary ' || TO_CHAR(p_week_start, 'YYYY-MM-DD'),
            v_summary, v_details)
    RETURNING id INTO v_report_id;

    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Update goal progress
CREATE OR REPLACE FUNCTION update_goal_progress(
    p_user_id UUID,
    p_device_id TEXT,
    p_goal_type TEXT,
    p_new_value DOUBLE PRECISION
)
RETURNS TABLE(goal_id UUID, goal_type TEXT, current_value DOUBLE PRECISION, target_value DOUBLE PRECISION, achieved BOOLEAN) AS $$
DECLARE
    v_goal RECORD;
    v_achieved BOOLEAN := false;
BEGIN
    FOR v_goal IN
        SELECT id, goal_type, target_value, current_value
        FROM goals
        WHERE user_id = p_user_id 
        AND device_id = p_device_id
        AND goal_type = p_goal_type
        AND is_active = true
        AND (end_date IS NULL OR end_date >= CURRENT_DATE)
    LOOP
        UPDATE goals
        SET current_value = p_new_value,
            achieved_at = CASE 
                WHEN p_new_value >= v_goal.target_value AND achieved_at IS NULL THEN NOW()
                ELSE achieved_at
            END
        WHERE id = v_goal.id;

        IF p_new_value >= v_goal.target_value AND v_goal.current_value < v_goal.target_value THEN
            v_achieved := true;
        END IF;

        RETURN QUERY SELECT v_goal.id, v_goal.goal_type, p_new_value, v_goal.target_value, v_achieved;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function: Check and unlock achievements
CREATE OR REPLACE FUNCTION check_achievements(
    p_user_id UUID,
    p_device_id TEXT,
    p_trigger_key TEXT,
    p_progress DOUBLE PRECISION
)
RETURNS TABLE(achievement_key TEXT, unlocked BOOLEAN) AS $$
DECLARE
    v_achievement RECORD;
    v_unlocked BOOLEAN := false;
BEGIN
    FOR v_achievement IN
        SELECT id, achievement_key, progress_current, progress_target, is_unlocked
        FROM achievements
        WHERE user_id = p_user_id 
        AND achievement_key LIKE p_trigger_key || '%'
        AND is_unlocked = false
    LOOP
        UPDATE achievements
        SET progress_current = LEAST(p_progress, progress_target)
        WHERE id = v_achievement.id;

        IF p_progress >= v_achievement.progress_target THEN
            UPDATE achievements
            SET is_unlocked = true, unlocked_at = NOW()
            WHERE id = v_achievement.id;
            v_unlocked := true;
        END IF;

        RETURN QUERY SELECT v_achievement.achievement_key, v_unlocked;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function: Get analytics for dashboard
CREATE OR REPLACE FUNCTION get_dashboard_analytics(
    p_user_id UUID,
    p_device_id TEXT,
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE(
    date DATE,
    metrics JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.date,
        jsonb_object_agg(a.metric_name, a.value) as metrics
    FROM analytics_summaries a
    WHERE a.user_id = p_user_id 
    AND a.device_id = p_device_id
    AND a.date >= CURRENT_DATE - (p_days || ' days')::INTERVAL
    GROUP BY a.date
    ORDER BY a.date DESC;
END;
$$ LANGUAGE plpgsql;

-- Comment
COMMENT ON TABLE telemetry_events IS 'Desktop Goose telemetry - feature usage, errors, sessions, performance';
COMMENT ON TABLE analytics_summaries IS 'Daily aggregated analytics for user productivity and habits';
COMMENT ON TABLE reports IS 'Generated reports (weekly summaries, habit analysis, etc.)';
COMMENT ON TABLE goals IS 'User goals and targets with progress tracking';
COMMENT ON TABLE achievements IS 'Gamification - achievement badges and progress';

-- Comment
COMMENT ON TABLE users IS 'Desktop Goose users - can be anonymous (device-based)';
COMMENT ON TABLE sync_data IS 'Synchronized user data (notes, habits, stats, etc.)';
COMMENT ON TABLE sync_history IS 'Audit log of sync operations';

-- =============================================
-- OpenTelemetry Tables
-- =============================================

-- Telemetry events (feature usage, errors, sessions)
CREATE TABLE IF NOT EXISTS telemetry_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    session_id UUID,
    event_type TEXT NOT NULL CHECK (event_type IN ('SessionStart', 'SessionEnd', 'FeatureUsed', 'WindowInteraction', 'Error', 'Performance')),
    module_name TEXT NOT NULL,
    feature_name TEXT NOT NULL,
    properties JSONB DEFAULT '{}',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Telemetry metrics (counters, gauges)
CREATE TABLE IF NOT EXISTS telemetry_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_type TEXT NOT NULL CHECK (metric_type IN ('counter', 'gauge', 'histogram')),
    value DOUBLE PRECISION NOT NULL,
    unit TEXT,
    tags JSONB DEFAULT '{}',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Telemetry spans (distributed tracing)
CREATE TABLE IF NOT EXISTS telemetry_spans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    trace_id UUID DEFAULT uuid_generate_v4(),
    span_id UUID DEFAULT uuid_generate_v4(),
    parent_span_id UUID,
    operation_name TEXT NOT NULL,
    service_name TEXT DEFAULT 'desktop-goose',
    duration_ms DOUBLE PRECISION,
    status TEXT DEFAULT 'ok' CHECK (status IN ('ok', 'error', 'timeout')),
    attributes JSONB DEFAULT '{}',
    events JSONB DEFAULT '[]',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Telemetry logs/events
CREATE TABLE IF NOT EXISTS telemetry_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    trace_id UUID,
    span_id UUID,
    log_level TEXT NOT NULL CHECK (log_level IN ('debug', 'info', 'warn', 'error')),
    message TEXT NOT NULL,
    source TEXT,
    attributes JSONB DEFAULT '{}',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Telemetry batch uploads (for 7-day sync)
CREATE TABLE IF NOT EXISTS telemetry_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    batch_type TEXT NOT NULL CHECK (batch_type IN ('metrics', 'spans', 'logs')),
    record_count INTEGER NOT NULL,
    data JSONB NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'uploaded', 'failed')),
    error_message TEXT
);

-- Indexes for telemetry tables
CREATE INDEX IF NOT EXISTS idx_telemetry_events_device_time ON telemetry_events(device_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_telemetry_events_session ON telemetry_events(session_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_events_type ON telemetry_events(event_type);
CREATE INDEX IF NOT EXISTS idx_telemetry_events_module ON telemetry_events(module_name, feature_name);
CREATE INDEX IF NOT EXISTS idx_telemetry_metrics_device_time ON telemetry_metrics(device_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_telemetry_metrics_name ON telemetry_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_telemetry_spans_device_time ON telemetry_spans(device_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_telemetry_spans_trace ON telemetry_spans(trace_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_logs_device_time ON telemetry_logs(device_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_telemetry_logs_level ON telemetry_logs(log_level);
CREATE INDEX IF NOT EXISTS idx_telemetry_batches_device ON telemetry_batches(device_id, uploaded_at);

-- Enable RLS on telemetry tables
ALTER TABLE telemetry_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_spans ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_batches ENABLE ROW LEVEL SECURITY;

-- RLS Policies for telemetry (allow anonymous device-based writes)
CREATE POLICY "Devices can insert telemetry events" ON telemetry_events
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Devices can view own telemetry events" ON telemetry_events
    FOR SELECT USING (device_id = current_setting('app.settings.device_id', true));

CREATE POLICY "Devices can insert metrics" ON telemetry_metrics
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Devices can insert spans" ON telemetry_spans
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Devices can insert logs" ON telemetry_logs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Devices can insert batches" ON telemetry_batches
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Devices can view own telemetry" ON telemetry_metrics
    FOR SELECT USING (device_id = current_setting('app.settings.device_id', true));

CREATE POLICY "Devices can view own spans" ON telemetry_spans
    FOR SELECT USING (device_id = current_setting('app.settings.device_id', true));

CREATE POLICY "Devices can view own logs" ON telemetry_logs
    FOR SELECT USING (device_id = current_setting('app.settings.device_id', true));

-- Grant permissions
GRANT ALL ON telemetry_events TO service_role;
GRANT ALL ON telemetry_metrics TO service_role;
GRANT ALL ON telemetry_spans TO service_role;
GRANT ALL ON telemetry_logs TO service_role;
GRANT ALL ON telemetry_batches TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- =============================================
-- Notifications & Events Tables
-- =============================================

-- Push Notification Subscriptions (WebPush)
CREATE TABLE IF NOT EXISTS notification_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT,
    auth TEXT,
    subscription_json JSONB,
    subscribed_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, endpoint)
);

-- Webhook Endpoints
CREATE TABLE IF NOT EXISTS webhooks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    events TEXT[] NOT NULL,           -- ['sync.completed', 'habit.streak', 'goal.achieved', 'report.generated']
    secret TEXT,
    enabled BOOLEAN DEFAULT true,
    last_triggered_at TIMESTAMPTZ,
    failure_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Scheduled Tasks (Reminders, Backups, Reports)
CREATE TABLE IF NOT EXISTS scheduled_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    task_type TEXT NOT NULL,           -- 'reminder', 'backup', 'report', 'habit_check', 'sync'
    task_name TEXT,
    cron_expression TEXT NOT NULL,    -- '0 9 * * *' = daily at 9am
    payload JSONB,
    enabled BOOLEAN DEFAULT true,
    last_run TIMESTAMPTZ,
    next_run TIMESTAMPTZ,
    run_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Event Log (for event sourcing)
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    event_type TEXT NOT NULL,          -- 'sync.started', 'sync.completed', 'habit.completed', 'goal.achieved'
    event_source TEXT,                 -- 'client', 'server', 'scheduler'
    payload JSONB DEFAULT '{}',
    processed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notification History
CREATE TABLE IF NOT EXISTS notification_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    notification_type TEXT NOT NULL,  -- 'push', 'webhook', 'in_app'
    title TEXT,
    body TEXT,
    data JSONB,
    status TEXT DEFAULT 'pending',     -- 'pending', 'sent', 'failed', 'clicked'
    sent_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notification_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_device ON notification_subscriptions(device_id);
CREATE INDEX IF NOT EXISTS idx_webhooks_user ON webhooks(user_id);
CREATE INDEX IF NOT EXISTS idx_webhooks_events ON webhooks USING GIN(events);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_user ON scheduled_tasks(user_id, enabled);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_next ON scheduled_tasks(next_run) WHERE enabled = true;
CREATE INDEX IF NOT EXISTS idx_events_user_type ON events(user_id, event_type);
CREATE INDEX IF NOT EXISTS idx_events_created ON events(created_at);
CREATE INDEX IF NOT EXISTS idx_notification_history_user ON notification_history(user_id, created_at);

-- Enable RLS on Notifications tables
ALTER TABLE notification_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Notifications
CREATE POLICY "Users can view own subscriptions" ON notification_subscriptions
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert subscriptions" ON notification_subscriptions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own webhooks" ON webhooks
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert webhooks" ON webhooks
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can update own webhooks" ON webhooks
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can delete own webhooks" ON webhooks
    FOR DELETE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can view own scheduled tasks" ON scheduled_tasks
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert scheduled tasks" ON scheduled_tasks
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can update own scheduled tasks" ON scheduled_tasks
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can delete own scheduled tasks" ON scheduled_tasks
    FOR DELETE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert events" ON events
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own events" ON events
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can view own notification history" ON notification_history
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert notification history" ON notification_history
    FOR INSERT WITH CHECK (true);

-- Grant permissions
GRANT ALL ON notification_subscriptions TO service_role;
GRANT ALL ON webhooks TO service_role;
GRANT ALL ON scheduled_tasks TO service_role;
GRANT ALL ON events TO service_role;
GRANT ALL ON notification_history TO service_role;

-- =============================================
-- Notifications & Events Functions
-- =============================================

-- Function: Register push subscription
CREATE OR REPLACE FUNCTION register_push_subscription(
    p_user_id UUID,
    p_device_id TEXT,
    p_endpoint TEXT,
    p_p256dh TEXT DEFAULT NULL,
    p_auth TEXT DEFAULT NULL,
    p_subscription_json JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_sub_id UUID;
BEGIN
    INSERT INTO notification_subscriptions (user_id, device_id, endpoint, p256dh, auth, subscription_json)
    VALUES (p_user_id, p_device_id, p_endpoint, p_p256dh, p_auth, p_subscription_json)
    ON CONFLICT (user_id, endpoint) DO UPDATE
    SET is_active = true, subscribed_at = NOW()
    RETURNING id INTO v_sub_id;

    RETURN v_sub_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Log event
CREATE OR REPLACE FUNCTION log_event(
    p_user_id UUID,
    p_device_id TEXT,
    p_event_type TEXT,
    p_event_source TEXT DEFAULT 'client',
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO events (user_id, device_id, event_type, event_source, payload)
    VALUES (p_user_id, p_device_id, p_event_type, p_event_source, p_payload)
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get events for processing
CREATE OR REPLACE FUNCTION get_pending_events(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE(
    id UUID,
    event_type TEXT,
    event_source TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT e.id, e.event_type, e.event_source, e.payload, e.created_at
    FROM events e
    WHERE e.user_id = p_user_id
    AND e.processed = false
    ORDER BY e.created_at ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Mark events as processed
CREATE OR REPLACE FUNCTION mark_events_processed(
    p_event_ids UUID[]
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE events
    SET processed = true
    WHERE id = ANY(p_event_ids)
    RETURNING COUNT(*) INTO v_count;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Create scheduled task
CREATE OR REPLACE FUNCTION create_scheduled_task(
    p_user_id UUID,
    p_device_id TEXT,
    p_task_type TEXT,
    p_task_name TEXT,
    p_cron_expression TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID AS $$
DECLARE
    v_task_id UUID;
    v_next_run TIMESTAMPTZ;
BEGIN
    v_next_run = NOW() + INTERVAL '1 hour';

    INSERT INTO scheduled_tasks (user_id, device_id, task_type, task_name, cron_expression, payload, next_run)
    VALUES (p_user_id, p_device_id, p_task_type, p_task_name, p_cron_expression, p_payload, v_next_run)
    RETURNING id INTO v_task_id;

    RETURN v_task_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get due scheduled tasks
CREATE OR REPLACE FUNCTION get_due_scheduled_tasks(
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    id UUID,
    user_id UUID,
    device_id TEXT,
    task_type TEXT,
    task_name TEXT,
    payload JSONB,
    cron_expression TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.user_id, t.device_id, t.task_type, t.task_name, t.payload, t.cron_expression
    FROM scheduled_tasks t
    WHERE t.enabled = true
    AND t.next_run <= NOW()
    ORDER BY t.next_run ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Record notification sent
CREATE OR REPLACE FUNCTION record_notification(
    p_user_id UUID,
    p_device_id TEXT,
    p_notification_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID AS $$
DECLARE
    v_notif_id UUID;
BEGIN
    INSERT INTO notification_history (user_id, device_id, notification_type, title, body, data, status, sent_at)
    VALUES (p_user_id, p_device_id, p_notification_type, p_title, p_body, p_data, 'sent', NOW())
    RETURNING id INTO v_notif_id;

    RETURN v_notif_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get webhook endpoints for event
CREATE OR REPLACE FUNCTION get_webhooks_for_event(
    p_user_id UUID,
    p_event_type TEXT
)
RETURNS TABLE(
    id UUID,
    name TEXT,
    url TEXT,
    secret TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT w.id, w.name, w.url, w.secret
    FROM webhooks w
    WHERE w.user_id = p_user_id
    AND w.enabled = true
    AND p_event_type = ANY(w.events);
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating updated_at
CREATE TRIGGER update_webhooks_updated_at BEFORE UPDATE ON webhooks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scheduled_tasks_updated_at BEFORE UPDATE ON scheduled_tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comment
COMMENT ON TABLE notification_subscriptions IS 'WebPush notification subscriptions for devices';
COMMENT ON TABLE webhooks IS 'User-configured webhook endpoints for event notifications';
COMMENT ON TABLE scheduled_tasks IS 'Scheduled/cron tasks for reminders, backups, reports';
COMMENT ON TABLE events IS 'Event log for event sourcing and audit trail';
COMMENT ON TABLE notification_history IS 'History of sent notifications';

-- =============================================
-- Security & Storage Tables
-- =============================================

-- OAuth Provider Links
CREATE TABLE IF NOT EXISTS auth_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,             -- 'google', 'github', 'apple', 'microsoft'
    provider_id TEXT NOT NULL,
    provider_email TEXT,
    access_token TEXT ENCRYPTED WITH (ALGORITHM = 'AES256'),
    refresh_token TEXT ENCRYPTED WITH (ALGORITHM = 'AES256'),
    token_expires_at TIMESTAMPTZ,
    linked_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, provider)
);

-- API Keys (for external integrations)
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    key_hash TEXT NOT NULL,
    key_prefix TEXT NOT NULL,           -- First 8 chars for display
    name TEXT,
    description TEXT,
    permissions TEXT[] DEFAULT ARRAY['read'],  -- ['read', 'write', 'admin']
    rate_limit INTEGER DEFAULT 100,     -- requests per minute
    last_used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    device_id TEXT,
    action TEXT NOT NULL,               -- 'login', 'logout', 'sync', 'file_upload', 'file_download', 'settings_change', 'api_key_created', 'api_key_used', 'webhook_triggered'
    resource_type TEXT,                 -- 'user', 'device', 'sync_data', 'file', 'webhook', 'api_key'
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    location JSONB,                     -- {'country': 'DE', 'city': 'Berlin'}
    details JSONB DEFAULT '{}',
    success BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- File Storage Metadata
CREATE TABLE IF NOT EXISTS files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,            -- Path in storage backend
    mime_type TEXT,
    file_size BIGINT,
    checksum TEXT,                      -- SHA256 hash
    storage_backend TEXT DEFAULT 'local',  -- 'local', 's3', 'minio'
    storage_region TEXT,                -- 'us-east-1', 'eu-central-1', etc.
    is_public BOOLEAN DEFAULT false,
    expires_at TIMESTAMPTZ,
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0
);

-- Session Management
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    session_token TEXT NOT NULL,
    refresh_token TEXT,
    ip_address INET,
    user_agent TEXT,
    location JSONB,
    expires_at TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Access Tokens (short-lived)
CREATE TABLE IF NOT EXISTS access_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    token_hash TEXT NOT NULL,
    token_type TEXT DEFAULT 'access',   -- 'access', 'refresh', 'magic_link'
    scopes TEXT[],
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rate Limiting
CREATE TABLE IF NOT EXISTS rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT,
    endpoint TEXT NOT NULL,
    window_start TIMESTAMPTZ DEFAULT NOW(),
    request_count INTEGER DEFAULT 0,
    limit_value INTEGER DEFAULT 100,
    window_minutes INTEGER DEFAULT 1,
    blocked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, endpoint, window_start)
);

-- Indexes for Security
CREATE INDEX IF NOT EXISTS idx_auth_providers_user ON auth_providers(user_id, provider);
CREATE INDEX IF NOT EXISTS idx_api_keys_user ON api_keys(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys(key_hash) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_action ON audit_logs(user_id, action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_files_user ON files(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_files_team ON files(team_id);
CREATE INDEX IF NOT EXISTS idx_files_checksum ON files(checksum);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(session_token) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_access_tokens_hash ON access_tokens(token_hash, expires_at) WHERE used_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_rate_limits_user_endpoint ON rate_limits(user_id, endpoint);

-- Enable RLS on Security tables
ALTER TABLE auth_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE files ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Security
CREATE POLICY "Users can view own auth providers" ON auth_providers
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert own auth providers" ON auth_providers
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can view own api keys" ON api_keys
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert own api keys" ON api_keys
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can update own api keys" ON api_keys
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can delete own api keys" ON api_keys
    FOR DELETE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert audit logs" ON audit_logs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own audit logs" ON audit_logs
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can view own files" ON files
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)) OR is_public = true);

CREATE POLICY "Users can insert own files" ON files
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can update own files" ON files
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can delete own files" ON files
    FOR DELETE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can view own sessions" ON sessions
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can insert own sessions" ON sessions
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can update own sessions" ON sessions
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Users can view own access tokens" ON access_tokens
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

CREATE POLICY "Devices can insert access tokens" ON access_tokens
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Rate limit check" ON rate_limits
    FOR ALL USING (user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.settings.device_id', true)));

-- Grant permissions
GRANT ALL ON auth_providers TO service_role;
GRANT ALL ON api_keys TO service_role;
GRANT ALL ON audit_logs TO service_role;
GRANT ALL ON files TO service_role;
GRANT ALL ON sessions TO service_role;
GRANT ALL ON access_tokens TO service_role;
GRANT ALL ON rate_limits TO service_role;

-- =============================================
-- Security & Storage Functions
-- =============================================

-- Function: Hash API key
CREATE OR REPLACE FUNCTION hash_api_key(p_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(digest(p_key, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function: Generate API key
CREATE OR REPLACE FUNCTION generate_api_key(
    p_user_id UUID,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_permissions TEXT[] DEFAULT ARRAY['read'],
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(key_id UUID, api_key TEXT, key_prefix TEXT) AS $$
DECLARE
    v_key_id UUID;
    v_api_key TEXT;
    v_key_hash TEXT;
    v_key_prefix TEXT;
BEGIN
    v_api_key = 'gk_' || encode(gen_random_bytes(24), 'base64url');
    v_key_hash = encode(digest(v_api_key, 'sha256'), 'hex');
    v_key_prefix = LEFT(v_api_key, 12);

    INSERT INTO api_keys (user_id, key_hash, key_prefix, name, description, permissions, expires_at)
    VALUES (p_user_id, v_key_hash, v_key_prefix, p_name, p_description, p_permissions, p_expires_at)
    RETURNING id INTO v_key_id;

    RETURN QUERY SELECT v_key_id, v_api_key, v_key_prefix;
END;
$$ LANGUAGE plpgsql;

-- Function: Validate API key
CREATE OR REPLACE FUNCTION validate_api_key(p_api_key TEXT)
RETURNS TABLE(user_id UUID, key_id UUID, permissions TEXT[]) AS $$
DECLARE
    v_key_hash TEXT;
BEGIN
    v_key_hash = encode(digest(p_api_key, 'sha256'), 'hex');

    RETURN QUERY
    SELECT k.user_id, k.id, k.permissions
    FROM api_keys k
    WHERE k.key_hash = v_key_hash
    AND k.is_active = true
    AND (k.expires_at IS NULL OR k.expires_at > NOW())
    LIMIT 1;

    IF FOUND THEN
        UPDATE api_keys
        SET last_used_at = NOW()
        WHERE key_hash = v_key_hash;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Log audit event
CREATE OR REPLACE FUNCTION log_audit_event(
    p_user_id UUID,
    p_device_id TEXT,
    p_action TEXT,
    p_resource_type TEXT DEFAULT NULL,
    p_resource_id UUID DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_details JSONB DEFAULT '{}'::JSONB,
    p_success BOOLEAN DEFAULT true
)
RETURNS UUID AS $$
DECLARE
    v_audit_id UUID;
BEGIN
    INSERT INTO audit_logs (user_id, device_id, action, resource_type, resource_id, ip_address, user_agent, details, success)
    VALUES (p_user_id, p_device_id, p_action, p_resource_type, p_resource_id, p_ip_address, p_user_agent, p_details, p_success)
    RETURNING id INTO v_audit_id;

    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Create session
CREATE OR REPLACE FUNCTION create_session(
    p_user_id UUID,
    p_device_id TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_days_valid INTEGER DEFAULT 30
)
RETURNS TABLE(session_id UUID, session_token TEXT, refresh_token TEXT) AS $$
DECLARE
    v_session_id UUID;
    v_session_token TEXT;
    v_refresh_token TEXT;
BEGIN
    v_session_token = encode(gen_random_bytes(32), 'hex');
    v_refresh_token = encode(gen_random_bytes(32), 'hex');

    INSERT INTO sessions (user_id, device_id, session_token, refresh_token, ip_address, user_agent, expires_at)
    VALUES (p_user_id, p_device_id, v_session_token, v_refresh_token, p_ip_address, p_user_agent, NOW() + (p_days_valid || ' days')::INTERVAL)
    RETURNING id INTO v_session_id;

    RETURN QUERY SELECT v_session_id, v_session_token, v_refresh_token;
END;
$$ LANGUAGE plpgsql;

-- Function: Validate session
CREATE OR REPLACE FUNCTION validate_session(p_session_token TEXT)
RETURNS TABLE(user_id UUID, device_id TEXT, session_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT s.user_id, s.device_id, s.id
    FROM sessions s
    WHERE s.session_token = p_session_token
    AND s.is_active = true
    AND s.expires_at > NOW()
    LIMIT 1;

    IF FOUND THEN
        UPDATE sessions
        SET last_activity_at = NOW()
        WHERE session_token = p_session_token;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Revoke session
CREATE OR REPLACE FUNCTION revoke_session(p_session_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE sessions
    SET is_active = false
    WHERE id = p_session_id;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function: Check rate limit
CREATE OR REPLACE FUNCTION check_rate_limit(
    p_user_id UUID,
    p_device_id TEXT,
    p_endpoint TEXT,
    p_limit INTEGER DEFAULT 100,
    p_window_minutes INTEGER DEFAULT 1
)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_count INTEGER;
    v_blocked_until TIMESTAMPTZ;
BEGIN
    SELECT request_count, blocked_until INTO v_current_count, v_blocked_until
    FROM rate_limits
    WHERE user_id = p_user_id
    AND endpoint = p_endpoint
    AND window_start > NOW() - (p_window_minutes || ' minutes')::INTERVAL;

    IF v_blocked_until IS NOT NULL AND v_blocked_until > NOW() THEN
        RETURN false;
    END IF;

    IF v_current_count IS NULL THEN
        INSERT INTO rate_limits (user_id, device_id, endpoint, request_count, limit_value, window_minutes)
        VALUES (p_user_id, p_device_id, p_endpoint, 1, p_limit, p_window_minutes);
        RETURN true;
    END IF;

    IF v_current_count >= p_limit THEN
        UPDATE rate_limits
        SET blocked_until = NOW() + (p_window_minutes || ' minutes')::INTERVAL
        WHERE user_id = p_user_id AND endpoint = p_endpoint;
        RETURN false;
    END IF;

    UPDATE rate_limits
    SET request_count = request_count + 1
    WHERE user_id = p_user_id AND endpoint = p_endpoint;

    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function: Record file upload
CREATE OR REPLACE FUNCTION record_file_upload(
    p_user_id UUID,
    p_file_name TEXT,
    p_file_path TEXT,
    p_mime_type TEXT,
    p_file_size BIGINT,
    p_checksum TEXT,
    p_storage_backend TEXT DEFAULT 'local'
)
RETURNS UUID AS $$
DECLARE
    v_file_id UUID;
BEGIN
    INSERT INTO files (user_id, file_name, file_path, mime_type, file_size, checksum, storage_backend)
    VALUES (p_user_id, p_file_name, p_file_path, p_mime_type, p_file_size, p_checksum, p_storage_backend)
    RETURNING id INTO v_file_id;

    RETURN v_file_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Link OAuth provider
CREATE OR REPLACE FUNCTION link_oauth_provider(
    p_user_id UUID,
    p_provider TEXT,
    p_provider_id TEXT,
    p_provider_email TEXT DEFAULT NULL,
    p_access_token TEXT DEFAULT NULL,
    p_refresh_token TEXT DEFAULT NULL,
    p_token_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_link_id UUID;
BEGIN
    INSERT INTO auth_providers (user_id, provider, provider_id, provider_email, access_token, refresh_token, token_expires_at)
    VALUES (p_user_id, p_provider, p_provider_id, p_provider_email, p_access_token, p_refresh_token, p_token_expires_at)
    ON CONFLICT (user_id, provider) DO UPDATE
    SET provider_id = EXCLUDED.provider_id,
        provider_email = EXCLUDED.provider_email,
        access_token = EXCLUDED.access_token,
        refresh_token = EXCLUDED.refresh_token,
        token_expires_at = EXCLUDED.token_expires_at,
        linked_at = NOW()
    RETURNING id INTO v_link_id;

    RETURN v_link_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating updated_at
CREATE TRIGGER update_api_keys_updated_at BEFORE UPDATE ON api_keys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_files_updated_at BEFORE UPDATE ON files
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comment
COMMENT ON TABLE auth_providers IS 'OAuth provider links for user authentication';
COMMENT ON TABLE api_keys IS 'API keys for external integrations';
COMMENT ON TABLE audit_logs IS 'Audit trail for security and compliance';
COMMENT ON TABLE files IS 'File metadata and storage information';
COMMENT ON TABLE sessions IS 'User session management';
COMMENT ON TABLE access_tokens IS 'Short-lived access and refresh tokens';
COMMENT ON TABLE rate_limits IS 'Rate limiting per user and endpoint';
