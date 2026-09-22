import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'PCLogger.dart';
import 'pc_extension_help.dart';

final trigger = PCThresholdTrigger();

class PCLocalProvider extends ChangeNotifier {
  // 1. 私有构造函数（禁止外部直接创建实例）
  PCLocalProvider._();

  // 2. 静态单例实例
  static final PCLocalProvider _instance = PCLocalProvider._();

  // 3. 提供全局访问点
  static PCLocalProvider get instance => _instance;

  bool _isShowingFirstAwardDialog = false;
  bool _isShowingRevenueMilestoneFlow = false;

  String pc_account_id = '';
  String pc_tx_list = "";
  String pc_ratio_str = "90";

  bool pc_bg_music = true; // 存储的本地值
  bool pc_sound_music = true; // 存储的本地值
  bool pc_login_status = false; // 存储的本地值
  bool pc_scratch_status_0 = true;
  bool pc_scratch_status_1 = true;
  bool pc_scratch_status_2 = true;
  bool pc_scratch_status_3 = true;
  bool pc_scratch_status_4 = true;
  bool pc_scratch_status_5 = true;
  bool pc_scratch_status_6 = true;
  bool pc_scratch_status_7 = true;
  bool pc_scratch_status_8 = true;
  bool pc_scratch_guide = true;
  bool pc_old_guide = true;
  bool pc_new_guide = false;
  bool is_end_Scratch = true;
  bool pc_show_dolpc_ani = false;
  bool pc_show_bubble = false;
  bool pc_show_box_guide = false;
  bool pc_cloak_status = false;
  bool pc_fk_number_status = false;
  bool pc_fk_decvice_status = false;
  bool pc_fk_ip_status = false;
  bool pc_fk_ad_short_show = false;
  bool pc_fk_ad_short_close = false;
  bool pc_dolpc_800 = false;
  bool pc_dolpc_1000 = false;
  bool pc_yunying_3 = false;
  bool pc_yunying_1 = false;
  bool pc_100_timer_star = false;
  bool pc_txing_status = false;
  bool pc_tx_first_status = false;
  bool pc_tx_last_status = false;
  bool pc_show_box_tips = false;
  bool pc_first_box_tips = false;
  bool pc_first_show_cash = false;
  bool pc_first_show_award = false;
  bool pc_first_show_rank = false;
  bool pc_first_show_box = false;
  bool pc_open_tx = false;
  bool pc_tx_task2_tips = false;
  bool pc_last_tx_end = false;
  bool pc_show_box = false;
  bool pc_tx_task3_tips = false;
  bool pc_tx_task4_tips = false;
  bool pc_tx_end_status = false;
  bool pc_afSwitch = true;
  bool pc_set_root = false;
  bool pc_af_status = false;
  bool pc_newA_guide = false;
  bool pc_good_review_status = false;
  bool pc_show_80_pop = false;
  bool pc_show_rank = false;
  bool pc_tx_ing_status = false;
  bool pc_install_status = false;
  bool pc_dolpc_80_end = false;

  int pc_scrach_all_count = 0; // 存储的本地值

  int pc_scrach_unlock_index_0 = 0; // 存储的本地值
  int pc_scrach_unlock_index_1 = 0; // 存储的本地值
  int pc_ad_all_number = 0;
  double pc_dollar_number = 0.00;
  double pc_dolpc_old_number = 0.0;
  double add_olduser_point = 3.0;
  int pc_ad_reawrd_all_number = 0;
  int pc_ad_short_show_number = 0;
  int pc_ad_short_close_number = 0;
  int pc_ad_show_index = 0;
  int pc_ad_show_number = 0;
  int pc_key_number = 0;
  int pc_account_seled_index = 0;
  int pc_tx_ing_account = 0;
  int pc_tx_pending_account = 0;
  int pc_tx_ing_number = 0;
  int pc_tx_task_index = 0;
  int pc_current_ranking = 99;
  int pc_all_ranking = 388;
  int pc_rank_ad_count = 0;
  int pc_tx_card_index = 0;
  int pc_tx_wheel_index = 0;
  int pc_tx_bubble_index = 0;
  int pc_box_index = 0;
  int pc_card_number = 0;
  int pc_Level_number = 1; // 存储的本地值
  int pc_Level_inedx = 1; // 存储的本地值
  int pc_dice_number = 0;
  int pc_card_a_number = 0;
  int pc_scrach_end_number_0 = 0; // 存储的本地值
  int pc_scrach_end_number_1 = 0; // 存储的本地值
  int pc_scrach_end_number_2 = 0; // 存储的本地值
  int pc_scrach_end_number_3 = 0; // 存储的本地值
  int pc_scrach_end_number_4 = 0; // 存储的本地值
  int pc_scrach_end_number_5 = 0; // 存储的本地值
  int pc_currentNumberIndex = 0;
  int pc_domand_number = 0;
  int pc_tx_card_first = 0;
  int pc_tx_dice_index = 0;
  int pc_quiz_task_index = 0;
  int new_ad_console = 1;
  int pc_zhuan_number = 0;
  int pc_quiz_tap_index = 0;
  int pc_tx_box_index = 0;

  int pc_scratch_box_index = 0;

  int pc_scratch_gua_index = 0;

  int card_push_number = 8;

  int pc_scratch_not_award_number = 0;

  // 主题类型
  int pc_quiz_model_index = 0;

  int pc_scratch_num_row = 0;

  int pc_scratch_num_index = 0;

  // 当前第几题
  int pc_quiz_num_index = 0;
  int pc_quzi_row = 0;
  int pc_wheel_number = 0;
  int pc_pig_level = 0;
  double pc_pig_level_index = 0.0;
  int pc_quiz_all_num = 0;
  int quiz_console = 5;
  int pc_dice_index = 0;
  int pc_dice_shou_index = 0;

  // 每日小任务：0-5刮卡、6转盘、7宝箱、8骰子
  List<int> pc_task_progress = List<int>.filled(9, 0);
  List<bool> pc_task_claimed = List<bool>.filled(9, false);
  bool pc_task_pig_claimed = false;

  int get pc_task_pig_progress {
    final completedCount = pc_task_progress
        .where((progress) => progress >= 3)
        .length;
    return min(completedCount, 9);
  }

  String pc_scrach_end_time_0 = ''; // 存储的本地值
  String pc_scrach_end_time_1 = ''; // 存储的本地值
  String pc_scrach_end_time_2 = ''; // 存储的本地值
  String pc_scrach_end_time_3 = ''; // 存储的本地值
  String pc_scrach_end_time_4 = ''; // 存储的本地值
  String pc_scrach_end_time_5 = ''; // 存储的本地值

  // 加速卡
  double pc_card_quicken_num = 0.0;

  bool pc_card_quicken_30 = false;

  bool pc_card_quicken_50 = false;

  bool pc_card_quicken_80 = false;

  bool pc_card_quicken_90 = false;

  bool pc_card_quicken_1 = false;

  bool pc_card_quicken_01 = false;

  bool pc_first_show_home = false;

  bool pc_new_guide_end = false;

  int pc_qunm_ad_index = 0;

  String get pc_currentNumberIndexName => 'pc_currentNumberIndex';

  String get pc_dice_numberName => 'pc_dice_number';

  String get pc_domand_numberName => 'pc_domand_number';

  String get pc_sound_musicName => 'pc_sound_music';

  String get pc_bg_musicName => 'pc_bg_music';

  String get pc_Level_numberName => 'pc_Level_number';

  String get pc_Level_inedxName => 'pc_Level_inedx';

  String get pc_fk_number_statusName => 'pc_fk_number_status';

  String get pc_fk_ip_statusName => 'pc_fk_ip_status';

  String get pc_fk_decvice_statusName => 'pc_fk_decvice_status';

  String get pc_ad_show_numberName => 'pc_ad_show_number';

  String get pc_ad_all_numberName => 'pc_ad_all_number';

  String get pc_ad_show_indexName => 'pc_ad_show_index';

  String get pc_ad_reawrd_all_numberName => 'pc_ad_reawrd_all_number';

  String get pc_ad_short_show_numberName => 'pc_ad_short_show_number';

  String get pc_fk_ad_short_showName => 'pc_fk_ad_short_show';

  String get pc_ad_short_close_numberName => 'pc_ad_short_close_number';

  String get pc_fk_ad_short_closeName => 'pc_fk_ad_short_close';

  String get pc_new_guideName => 'pc_new_guide';

  String get pc_ratio_strName => 'pc_ratio_str';

  String get pc_dolpc_1000Name => 'pc_dolpc_1000';

  String get pc_dolpc_800Name => 'pc_dolpc_800';

  String get pc_100_timer_starName => 'pc_100_timer_star';

  String get pc_dollar_numberName => 'pc_dollar_number';

  String get pc_card_numberName => 'pc_card_number';

  String get pc_show_dolpc_aniName => 'pc_show_dolpc_ani';

  String get pc_box_indexName => 'pc_box_index';

  String get pc_txing_statusName => 'pc_txing_status';

  String get pc_tx_ing_numberName => 'pc_tx_ing_number';

  String get pc_account_seled_indexName => 'pc_account_seled_index';

  String get pc_tx_ing_accountName => 'pc_tx_ing_account';

  String get pc_tx_pending_accountName => 'pc_tx_pending_account';

  String get pc_tx_bubble_indexName => 'pc_tx_bubble_index';

  String get pc_tx_card_indexName => 'pc_tx_card_index';

  String get pc_tx_wheel_indexName => 'pc_tx_wheel_index';

  String get pc_tx_task_indexName => 'pc_tx_task_index';

  String get pc_tx_card_firstName => 'pc_tx_card_first';

  String get pc_account_idName => 'pc_account_id';

  String get pc_tx_listName => 'pc_tx_list';

  String get pc_revenue_milestone_pendingName => 'pc_revenue_milestone_pending';

  String get pc_revenue_progress_pendingName => 'pc_revenue_progress_pending';

  String get pc_revenue_progress_500_shownName =>
      'pc_revenue_progress_500_shown';

  String get pc_revenue_progress_900_shownName =>
      'pc_revenue_progress_900_shown';

  String get pc_withdraw_tips_pending_countName =>
      'pc_withdraw_tips_pending_count';

  String get pc_tx_dice_indexName => 'pc_tx_dice_index';

  String get pc_tx_first_statusName => 'pc_tx_first_status';

  String get pc_tx_last_statusName => 'pc_tx_last_status';

  String get pc_current_rankingName => 'pc_current_ranking';

  String get pc_all_rankingName => 'pc_all_ranking';

  String get pc_old_guideName => 'pc_old_guide';

  String get pc_scratch_not_award_numberName => 'pc_scratch_not_award_number';

  String get pc_cloak_statusName => 'pc_cloak_status';

  String get pc_show_box_tipsName => 'pc_show_box_tips';

  String get pc_first_box_tipsName => 'pc_first_box_tips';

  String get pc_first_show_cashName => 'pc_first_show_cash';

  String get pc_first_show_awardName => 'pc_first_show_award';

  String get pc_scratch_guideName => 'pc_scratch_guide';

  String get pc_open_txName => 'pc_open_tx';

  String get pc_tx_task2_tipsName => 'pc_tx_task2_tips';

  String get pc_last_tx_endName => 'pc_last_tx_end';

  String get is_end_ScratchName => 'is_end_Scratch';

  String get pc_yunying_1Name => 'pc_yunying_1';

  String get pc_yunying_3Name => 'pc_yunying_3';

  String get pc_show_boxName => 'pc_show_box';

  String get pc_tx_task3_tipsName => 'pc_tx_task3_tips';

  String get pc_tx_task4_tipsName => 'pc_tx_task4_tips';

  String get pc_tx_end_statusName => 'pc_tx_end_status';

  String get pc_dolpc_old_numberName => 'pc_dolpc_old_number';

  String get pc_afSwitchName => 'pc_afSwitch';

  String get pc_set_rootName => 'pc_set_root';

  String get pc_login_statusName => 'pc_login_status';

  String get pc_af_statusName => 'pc_af_status';

  String get pc_newA_guideName => 'pc_newA_guide';

  String get pc_good_review_statusName => 'pc_good_review_status';

  String get pc_card_a_numberName => 'pc_card_a_number';

  String get pc_quiz_model_indexName => 'pc_quiz_model_index';

  String get pc_quiz_num_indexName => 'pc_quiz_num_index';

  String get pc_quzi_rowName => 'pc_quzi_row';

  String get pc_wheel_numberName => 'pc_wheel_number';

  String get pc_pig_levelName => 'pc_pig_level';

  String get pc_pig_level_indexName => 'pc_pig_level_index';

  String get pc_quiz_task_indexName => 'pc_quiz_task_index';

  String get new_ad_consoleName => 'new_ad_console';

  String get pc_zhuan_numberName => 'pc_zhuan_number';

  String get pc_quiz_all_numName => 'pc_quiz_all_num';

  String get pc_quiz_tap_indexName => 'pc_quiz_tap_index';

  String get pc_show_80_popName => 'pc_show_80_pop';

  String get pc_show_rankName => 'pc_show_rank';

  String get pc_tx_ing_statusName => 'pc_tx_ing_status';

  String get add_olduser_pointName => 'add_olduser_point';

  String get pc_install_statusName => 'pc_install_status';

  String get quiz_consoleName => 'quiz_console';

  String get pc_tx_box_indexName => 'pc_tx_box_index';

  String get pc_scrach_end_number_0Name => 'pc_scrach_end_number_0';

  String get pc_scrach_end_number_1Name => 'pc_scrach_end_number_1';

  String get pc_scrach_end_number_2Name => 'pc_scrach_end_number_2';

  String get pc_scrach_end_number_3Name => 'pc_scrach_end_number_3';

  String get pc_scrach_end_number_4Name => 'pc_scrach_end_number_4';

  String get pc_scrach_end_number_5Name => 'pc_scrach_end_number_5';

  String get pc_scratch_box_indexName => 'pc_scratch_box_index';

  String get card_push_numberName => 'card_push_number';

  String get pc_scratch_gua_indexName => 'pc_scratch_gua_index';

  String get pc_dolpc_80_endName => 'pc_dolpc_80_end';

  String get pc_scratch_num_rowName => 'pc_scratch_num_row';

  String get pc_scratch_num_indexName => 'pc_scratch_num_index';

  String get pc_card_quicken_numName => 'pc_card_quicken_nums';

  String get pc_card_quicken_30Name => 'pc_card_quicken_30';

  String get pc_card_quicken_50Name => 'pc_card_quicken_50';

  String get pc_card_quicken_80Name => 'pc_card_quicken_80';

  String get pc_card_quicken_90Name => 'pc_card_quicken_90';

  String get pc_card_quicken_1Name => 'pc_card_quicken_1';

  String get pc_card_quicken_01Name => 'pc_card_quicken_01';

  String get pc_scrach_end_time_0Name => 'pc_scrach_end_time_0';

  String get pc_scrach_end_time_1Name => 'pc_scrach_end_time_1';

  String get pc_scrach_end_time_2Name => 'pc_scrach_end_time_2';

  String get pc_scrach_end_time_3Name => 'pc_scrach_end_time_3';

  String get pc_scrach_end_time_4Name => 'pc_scrach_end_time_4';

  String get pc_scrach_end_time_5Name => 'pc_scrach_end_time_5';

  String get pc_show_box_guideName => 'pc_show_box_guide';

  String get pc_qunm_ad_indexName => 'pc_qunm_ad_index';

  String get pc_first_show_rankName => 'pc_first_show_rank';

  String get pc_rank_ad_countName => 'pc_rank_ad_count';

  String get pc_first_show_homeName => 'pc_first_show_home';

  String get pc_new_guide_endName => 'pc_new_guide_end';

  String get pc_scrach_all_countName => 'pc_scrach_all_count';

  String get pc_dice_indexName => 'pc_dice_index';

  String get pc_first_show_boxName => 'pc_first_show_box';

  String get pc_dice_shou_indexName => 'pc_dice_shou_index';

  // 3. 初始化：从本地存储加载数据（组件初始化时调用）
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // 从本地读取值（key自定义，需与存储时一致）
    pc_tx_dice_index = prefs.getInt('pc_tx_dice_index') ?? 0;
    pc_tx_card_first = prefs.getInt('pc_tx_card_first') ?? 0;
    pc_domand_number = prefs.getInt('pc_domand_number') ?? 0;
    pc_dice_index = prefs.getInt('pc_dice_index') ?? 0;
    pc_dice_shou_index = prefs.getInt('pc_dice_shou_index') ?? 0;
    pc_scrach_all_count = prefs.getInt('pc_scrach_all_count') ?? 0;
    pc_dice_number = prefs.getInt('pc_dice_number') ?? 0;
    pc_card_number = prefs.getInt('pc_card_number') ?? 0;
    pc_box_index = prefs.getInt('pc_box_index') ?? 0;
    pc_tx_card_index = prefs.getInt('pc_tx_card_index') ?? 0;
    pc_wheel_number = prefs.getInt('pc_wheel_number') ?? 0;
    pc_pig_level = prefs.getInt('pc_pig_level') ?? 0;
    pc_tx_box_index = prefs.getInt('pc_tx_box_index') ?? 0;
    pc_pig_level_index = prefs.getDouble('pc_pig_level_index') ?? 0.0;
    add_olduser_point = prefs.getDouble('add_olduser_point') ?? 3.0;
    pc_tx_wheel_index = prefs.getInt('pc_tx_wheel_index') ?? 0;
    pc_tx_bubble_index = prefs.getInt('pc_tx_bubble_index') ?? 0;
    pc_current_ranking = prefs.getInt('pc_current_ranking') ?? 99;
    pc_all_ranking = prefs.getInt('pc_all_ranking') ?? 388;
    pc_rank_ad_count = prefs.getInt('pc_rank_ad_count') ?? 388;
    pc_tx_task_index = prefs.getInt('pc_tx_task_index') ?? 0;
    pc_quiz_task_index = prefs.getInt('pc_quiz_task_index') ?? 0;
    pc_tx_ing_account = prefs.getInt('pc_tx_ing_account') ?? 0;
    pc_tx_pending_account = prefs.getInt('pc_tx_pending_account') ?? 0;
    pc_tx_ing_number = prefs.getInt('pc_tx_ing_number') ?? 0;
    pc_card_a_number = prefs.getInt('pc_card_a_number') ?? 0;
    pc_quiz_model_index = prefs.getInt('pc_quiz_model_index') ?? 0;
    pc_quiz_num_index = prefs.getInt('pc_quiz_num_index') ?? 0;
    pc_zhuan_number = prefs.getInt('pc_zhuan_number') ?? 0;
    pc_quiz_all_num = prefs.getInt('pc_quiz_all_num') ?? 0;
    pc_quiz_tap_index = prefs.getInt('pc_quiz_tap_index') ?? 0;
    pc_scratch_box_index = prefs.getInt('pc_scratch_box_index') ?? 0;
    pc_qunm_ad_index = prefs.getInt('pc_qunm_ad_index') ?? 0;
    pc_scratch_not_award_number =
        prefs.getInt('pc_scratch_not_award_number') ?? 0;
    pc_account_seled_index = prefs.getInt('pc_account_seled_index') ?? 0;
    pc_scrach_unlock_index_0 = prefs.getInt('pc_scrach_unlock_index_0') ?? 0;
    pc_scrach_unlock_index_1 = prefs.getInt('pc_scrach_unlock_index_1') ?? 0;
    pc_ad_short_show_number = prefs.getInt('pc_ad_short_show_number') ?? 0;
    pc_ad_short_close_number = prefs.getInt('pc_ad_short_close_number') ?? 0;
    pc_ad_show_number = prefs.getInt('pc_ad_show_number') ?? 0;
    pc_key_number = prefs.getInt('pc_key_number') ?? 0;
    pc_quzi_row = prefs.getInt('pc_quzi_row') ?? 0;
    pc_wheel_number = prefs.getInt('pc_wheel_number') ?? 0;
    quiz_console = prefs.getInt('quiz_console') ?? 5;
    new_ad_console = prefs.getInt('new_ad_console') ?? 1;
    pc_bg_music = prefs.getBool('pc_bg_music') ?? true;
    pc_sound_music = prefs.getBool('pc_sound_music') ?? true;
    pc_tx_task3_tips = prefs.getBool('pc_tx_task3_tips') ?? false;
    pc_first_show_box = prefs.getBool('pc_first_show_box') ?? false;
    pc_first_show_award = prefs.getBool('pc_first_show_award') ?? false;
    pc_tx_task4_tips = prefs.getBool('pc_tx_task4_tips') ?? false;
    pc_txing_status = prefs.getBool('pc_txing_status') ?? false;
    pc_login_status = prefs.getBool('pc_login_status') ?? false;
    pc_first_show_home = prefs.getBool('pc_first_show_home') ?? false;
    pc_good_review_status = prefs.getBool('pc_good_review_status') ?? false;
    pc_open_tx = prefs.getBool('pc_open_tx') ?? false;
    pc_new_guide_end = prefs.getBool('pc_new_guide_end') ?? false;
    pc_first_show_rank = prefs.getBool('pc_first_show_rank') ?? false;
    pc_install_status = prefs.getBool('pc_install_status') ?? false;
    pc_show_box = prefs.getBool('pc_show_box') ?? false;
    pc_afSwitch = prefs.getBool('pc_afSwitch') ?? true;
    pc_set_root = prefs.getBool('pc_set_root') ?? false;
    pc_show_rank = prefs.getBool('pc_show_rank') ?? false;
    pc_af_status = prefs.getBool('pc_af_status') ?? false;
    is_end_Scratch = prefs.getBool('is_end_Scratch') ?? true;
    pc_cloak_status = prefs.getBool('pc_cloak_status') ?? false;
    pc_show_box_tips = prefs.getBool('pc_show_box_tips') ?? false;
    pc_first_box_tips = prefs.getBool('pc_first_box_tips') ?? false;
    pc_fk_number_status = prefs.getBool('pc_fk_number_status') ?? false;
    pc_fk_decvice_status = prefs.getBool('pc_fk_decvice_status') ?? false;
    pc_fk_ad_short_show = prefs.getBool('pc_fk_ad_short_show') ?? false;
    pc_fk_ad_short_close = prefs.getBool('pc_fk_ad_short_close') ?? false;
    pc_fk_ip_status = prefs.getBool('pc_fk_ip_status') ?? false;
    pc_newA_guide = prefs.getBool('pc_newA_guide') ?? false;
    pc_scratch_guide = prefs.getBool('pc_scratch_guide') ?? true;
    pc_old_guide = prefs.getBool('pc_old_guide') ?? true;
    pc_new_guide = prefs.getBool('pc_new_guide') ?? false;
    pc_show_bubble = prefs.getBool('pc_show_bubble') ?? false;
    pc_show_dolpc_ani = prefs.getBool('pc_show_dolpc_ani') ?? false;
    pc_show_box_guide = prefs.getBool('pc_show_box_guide') ?? false;
    pc_dolpc_800 = prefs.getBool('pc_dolpc_800') ?? false;
    pc_dolpc_1000 = prefs.getBool('pc_dolpc_1000') ?? false;
    pc_100_timer_star = prefs.getBool('pc_100_timer_star') ?? false;
    pc_tx_first_status = prefs.getBool('pc_tx_first_status') ?? false;
    pc_tx_last_status = prefs.getBool('pc_tx_last_status') ?? false;
    pc_first_show_cash = prefs.getBool('pc_first_show_cash') ?? false;
    pc_tx_task2_tips = prefs.getBool('pc_tx_task2_tips') ?? false;
    pc_last_tx_end = prefs.getBool('pc_last_tx_end') ?? false;
    pc_yunying_3 = prefs.getBool('pc_yunying_3') ?? false;
    pc_yunying_1 = prefs.getBool('pc_yunying_1') ?? false;
    pc_tx_end_status = prefs.getBool('pc_tx_end_status') ?? false;
    pc_show_80_pop = prefs.getBool('pc_show_80_pop') ?? false;
    pc_tx_ing_status = prefs.getBool('pc_tx_ing_status') ?? false;
    pc_ad_reawrd_all_number = prefs.getInt('pc_ad_reawrd_all_number') ?? 0;
    pc_ad_all_number = prefs.getInt('pc_ad_all_number') ?? 0;
    pc_dollar_number = prefs.getDouble('pc_dollar_number') ?? 0.00;
    pc_dolpc_old_number = prefs.getDouble('pc_dolpc_old_number') ?? 0.0;
    pc_ad_show_index = prefs.getInt('pc_ad_show_index') ?? 0;
    pc_Level_number = prefs.getInt('pc_Level_number') ?? 1;
    pc_Level_inedx = prefs.getInt('pc_Level_inedx') ?? 1;
    pc_scrach_end_number_0 = prefs.getInt('pc_scrach_end_number_0') ?? 0;
    pc_scrach_end_number_1 = prefs.getInt('pc_scrach_end_number_1') ?? 0;
    pc_scrach_end_number_2 = prefs.getInt('pc_scrach_end_number_2') ?? 0;
    pc_scrach_end_number_3 = prefs.getInt('pc_scrach_end_number_3') ?? 0;
    pc_scrach_end_number_4 = prefs.getInt('pc_scrach_end_number_4') ?? 0;
    pc_scrach_end_number_5 = prefs.getInt('pc_scrach_end_number_5') ?? 0;
    pc_currentNumberIndex = prefs.getInt('pc_currentNumberIndex') ?? 0;
    pc_scratch_status_0 = prefs.getBool('pc_scratch_status_0') ?? true;
    pc_scratch_status_1 = prefs.getBool('pc_scratch_status_1') ?? true;
    pc_scratch_status_2 = prefs.getBool('pc_scratch_status_2') ?? true;
    pc_scratch_status_3 = prefs.getBool('pc_scratch_status_3') ?? true;
    pc_scratch_status_4 = prefs.getBool('pc_scratch_status_4') ?? true;
    pc_scratch_status_5 = prefs.getBool('pc_scratch_status_5') ?? true;
    pc_scratch_status_6 = prefs.getBool('pc_scratch_status_6') ?? true;
    pc_scratch_status_7 = prefs.getBool('pc_scratch_status_7') ?? true;
    pc_scratch_status_8 = prefs.getBool('pc_scratch_status_8') ?? true;
    pc_dolpc_80_end = prefs.getBool('pc_dolpc_80_end') ?? true;
    pc_card_quicken_30 = prefs.getBool('pc_card_quicken_30') ?? false;
    pc_card_quicken_50 = prefs.getBool('pc_card_quicken_50') ?? false;
    pc_card_quicken_80 = prefs.getBool('pc_card_quicken_80') ?? false;
    pc_card_quicken_90 = prefs.getBool('pc_card_quicken_90') ?? false;
    pc_card_quicken_1 = prefs.getBool('pc_card_quicken_1') ?? false;
    pc_card_quicken_01 = prefs.getBool('pc_card_quicken_01') ?? false;
    pc_ratio_str = prefs.getString('pc_ratio_str') ?? '90';
    pc_account_id = prefs.getString('pc_account_id') ?? '';
    pc_tx_list = prefs.getString("pc_tx_list") ?? "";
    pc_scrach_end_time_0 = prefs.getString("pc_scrach_end_time_0") ?? "";
    pc_scrach_end_time_1 = prefs.getString("pc_scrach_end_time_1") ?? "";
    pc_scrach_end_time_2 = prefs.getString("pc_scrach_end_time_2") ?? "";
    pc_scrach_end_time_3 = prefs.getString("pc_scrach_end_time_3") ?? "";
    pc_scrach_end_time_4 = prefs.getString("pc_scrach_end_time_4") ?? "";
    pc_scrach_end_time_5 = prefs.getString("pc_scrach_end_time_5") ?? "";
    card_push_number = prefs.getInt('card_push_number') ?? 8;
    pc_scratch_gua_index = prefs.getInt('pc_scratch_gua_index') ?? 0;
    pc_scratch_num_row = prefs.getInt('pc_scratch_num_row') ?? 0;
    pc_scratch_num_index = prefs.getInt('pc_scratch_num_index') ?? 0;
    pc_task_progress = List<int>.generate(
      9,
      (index) => prefs.getInt('pc_task_progress_$index') ?? 0,
    );
    pc_task_claimed = List<bool>.generate(
      9,
      (index) => prefs.getBool('pc_task_claimed_$index') ?? false,
    );
    pc_task_pig_claimed = prefs.getBool('pc_task_pig_claimed') ?? false;
    pc_card_quicken_num = prefs.getDouble('pc_card_quicken_nums') ?? 0;
    Future.delayed(Duration(milliseconds: 100), () {
      notifyListeners(); // 加载完成后通知UI更新
    });
  }

  // 通用bool
  Future<bool> updateBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    bool reuslt = await prefs.setBool(key, value);
    init();
    return reuslt;
  }

  // 通用int
  Future<bool> updateint(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    bool reuslt = await prefs.setInt(key, value);
    init();
    return reuslt;
  }

  // 通用double
  Future<void> updatedouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    final isDollarReward =
        key == PCLocalProvider.instance.pc_dollar_numberName && value > 0;
    final shouldShowFirstAward =
        isDollarReward &&
        !(prefs.getBool(pc_first_show_awardName) ?? false) &&
        !_isShowingFirstAwardDialog;
    if (shouldShowFirstAward) {
      _isShowingFirstAwardDialog = true;
    }

    if (key == PCLocalProvider.instance.pc_dollar_numberName) {
      final oldBalance = prefs.getDouble(key) ?? pc_dollar_number;
      final newBalance = oldBalance + value;
      await prefs.setDouble(key, newBalance);
    } else {
      await prefs.setDouble(key, value);
    }
    await init();
  }


  // 通用String
  Future<bool> updateString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    bool reuslt = await prefs.setString(key, value);
    init();
    return reuslt;
  }
}

