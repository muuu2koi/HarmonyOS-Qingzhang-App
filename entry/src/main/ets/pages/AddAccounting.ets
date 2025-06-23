import router from '@ohos.router';
import { Popup } from '@kit.ArkUI'
import common from '@ohos.app.ability.common';
import relationalStore from '@ohos.data.relationalStore';
import { Bill, billDBService } from '../common/BillDBService';
import promptAction from '@ohos.promptAction';

interface BillRecord extends Bill {
  id: number;            // 数据库自增ID
}

// 插入账单的返回结果接口
interface InsertResult {
  success: boolean;
  message: string;
}

// 查询选项接口
interface QueryOptions {
  type?: '收入' | '支出';
  startDate?: string;
  endDate?: string;
}

// 插入账单
async function insertBill(bill: Bill): Promise<InsertResult> {
  try {
    console.info(`开始保存账单: ${JSON.stringify(bill)}`);
    const id = await billDBService.addBill(bill);
    console.info(`保存账单结果ID: ${id}`);
    return {
      success: id > 0,
      message: id > 0 ? '添加成功' : '添加失败'
    };
  } catch (error) {
    console.error(`插入账单失败: ${JSON.stringify(error)}`);
    return {
      success: false,
      message: '添加失败，请重试'
    };
  }
}

// 查询账单
async function queryBills(options?: QueryOptions): Promise<BillRecord[]> {
  try {
    return await billDBService.getAllBills(options);
  } catch (error) {
    console.error(`查询账单失败: ${JSON.stringify(error)}`);
    return [];
  }
}

// 删除账单
async function deleteBill(id: number): Promise<boolean> {
  try {
    return await billDBService.deleteBill(id);
  } catch (error) {
    console.error(`删除账单失败: ${JSON.stringify(error)}`);
    return false;
  }
}

// 更新账单
async function updateBill(id: number, bill: Partial<Bill>): Promise<boolean> {
  try {
    return await billDBService.updateBill(id, bill);
  } catch (error) {
    console.error(`更新账单失败: ${JSON.stringify(error)}`);
    return false;
  }
}

@Entry
@Component
struct AddAccounting{

  @State amount: string = '';
  @State note: string = '';
  @State selectedDate: Date = new Date();
  @State rdbStore: relationalStore.RdbStore | null = null;

  @State currentIndex: number = 0;//tab页签
  @State iconCurrentIndex : number = 0;//账单类别
  @State handlePopup1 : boolean = false
  @State handlePopup2 : boolean = false


  // 初始化数据库
  async aboutToAppear() {
    const context = getContext(this) as common.UIAbilityContext;
    await billDBService.initDB(context);
  }


  // 支出、收入tab构建
  @Builder
  tabBuilder(title:string,targetIndex: number){
    Column(){
      Button(title)
        .fontSize(18)
        .fontColor(Color.White)
        .backgroundColor(this.currentIndex === targetIndex ? Color.Black : '#cdcdcd')
        .width(120)
        .height(34)
        .margin({bottom:5})
    }
  }

  // 账单类型图标构建
  @Builder
  iconBuilder(iconSelected:Resource, icon:Resource, title:string, targetIndex:number) {
    Column() {
      Column() {
        Image(this.iconCurrentIndex === targetIndex ? iconSelected : icon)
          .width(25)
          .height(25)
          .animation({
            duration: 250,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .height(48)
      .width(48)
      .borderRadius(24)
      .backgroundColor(this.iconCurrentIndex === targetIndex ? Color.Black : '#cdcdcd')
      .animation({
        duration: 200,
        curve: Curve.FastOutSlowIn,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        animateTo({
          duration: 100,
          curve: Curve.Sharp,
          iterations: 1,
          playMode: PlayMode.Normal,
        }, () => {
          this.iconCurrentIndex = targetIndex;
        })
      })
      .gesture(
        TapGesture({ count: 1 })
          .onAction(() => {
            this.iconCurrentIndex = targetIndex;
          })
      )

      Text(title)
        .fontSize(13)
        .margin({top:5})
        .opacity(this.iconCurrentIndex === targetIndex ? 1 : 0.8)
        .animation({
          duration: 200,
          curve: Curve.EaseOut
        })
    }
    .gesture(
      TapGesture()
        .onAction(() => {
          this.iconCurrentIndex = targetIndex;
        })
    )
    .hitTestBehavior(HitTestMode.Transparent)
    .scale({
      x: this.iconCurrentIndex === targetIndex ? 1.05 : 1,
      y: this.iconCurrentIndex === targetIndex ? 1.05 : 1,
    })
    .animation({
      duration: 250,
      curve: Curve.EaseOut
    })
  }

  // 信息气泡构建
  @Builder
  popupWithButtonBuilder1() {
    Row() {
      Popup({
        title: {
          text: '保存成功',
        },
        message: {
          text: '您可继续添加账单'
        },
        showClose: true,
        onClose: () => {
          this.handlePopup1 = false;
        },
      })
    }
  }
  @Builder
  popupWithButtonBuilder2() {
    Row() {
      Popup({
        title: {
          text: '保存成功',
        },
        message: {
          text: '您可继续添加账单'
        },
        showClose: true,
        onClose: () => {
          this.handlePopup2 = false;
        },
      })
    }
  }


  // 保存支出账单
  async saveExpenseBill(): Promise<InsertResult> {
    if (!this.amount || parseFloat(this.amount) <= 0) {
      console.error(`账单金额无效: ${this.amount}`);
      return {
        success: false,
        message: '账单金额无效'
      };
    }

    // 根据当前选中的图标获取对应的类别名称
    const categoryNames: string[] = [
      '餐饮', '医疗', '交通', '住房',
      '零食烟酒', '学习', '通讯', '社交',
      '投资', '购物', '娱乐', '外借', '其他'
    ];
    
    const category = this.iconCurrentIndex < categoryNames.length 
      ? categoryNames[this.iconCurrentIndex] 
      : '其他';
    
    console.info(`保存支出账单，金额: ${this.amount}, 类别: ${category}`);
    
    const bill: Bill = {
      date: this.formatDate(this.selectedDate),
      type: '支出',
      category: category,
      amount: parseFloat(this.amount),
      remark: this.note
    };
    
    return await insertBill(bill);
  }
  
  // 保存收入账单
  async saveIncomeBill(): Promise<InsertResult> {
    if (!this.amount || parseFloat(this.amount) <= 0) {
      console.error('账单金额无效');
      return {
        success: false,
        message: '账单金额无效'
      };
    }
    
    // 收入类别名称数组
    const categoryNames: string[] = [
      '工资', '奖金', '投资', '租金',
      '报销', '退款', '红包', '利息',
      '交易', '奖学金', '分红', '其他'
    ];
    
    // 调整索引，因为收入图标索引从13开始
    const adjustedIndex = this.iconCurrentIndex - 13;
    const category = adjustedIndex >= 0 && adjustedIndex < categoryNames.length 
      ? categoryNames[adjustedIndex] 
      : '其他';
    
    const bill: Bill = {
      date: this.formatDate(this.selectedDate),
      type: '收入',
      category: category,
      amount: parseFloat(this.amount),
      remark: this.note
    };
    
    return await insertBill(bill);
  }
  
  // 日期格式化
  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  build() {
    Column(){
      // 标题返回部分
      Row(){
        Image($r('app.media.back')).width(35).height(35).margin({left:15,right:10})
          .onClick(()=>{
            router.back()
          })
        Text('添加账单').fontSize(20).fontWeight(600)
      }.justifyContent(FlexAlign.Start)
      .width('100%')
      .margin({bottom:20,top:15,left:10})

      Tabs(){
        ///////////////////////////////////////////////////////////////////////////////////////////
        // 支出页
        TabContent(){
          Column(){
            Column(){

              // 账单金额输入栏
              Row(){
                Text('账单金额:').fontSize(18)
                TextInput({placeholder:'￥0.00', text: this.amount})
                  .width('35%')
                  .backgroundColor('#f0f0f0')
                  .onChange((value: string) => {
                    this.amount = value;
                  })
              }.width('90%')
              .height('10%')
              .borderWidth({bottom:1})
              .borderColor('#bfbfbf')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({bottom:5})

              // 支出类别图标实现
              Row() {
                this.iconBuilder($r('app.media.cy_sl'),$r('app.media.cy'),'餐饮',0)
                this.iconBuilder($r('app.media.yl_sl'),$r('app.media.yl'),'医疗',1)
                this.iconBuilder($r('app.media.jt_sl'),$r('app.media.jt'),'交通',2)
                this.iconBuilder($r('app.media.zf_sl'),$r('app.media.zf'),'住房',3)
              }.justifyContent(FlexAlign.SpaceAround)
              .padding(10)
              .width('100%')
              Row() {
                this.iconBuilder($r('app.media.lsyj_sl'),$r('app.media.lsyj'),'零食烟酒',4)
                this.iconBuilder($r('app.media.xx_sl'),$r('app.media.xx'),'学习',5)
                this.iconBuilder($r('app.media.tx_sl'),$r('app.media.tx'),'通讯',6)
                this.iconBuilder($r('app.media.sj_sl'),$r('app.media.sj'),'社交',7)
              }.justifyContent(FlexAlign.SpaceAround)
              .padding(10)
              .width('100%')
              Row() {
                this.iconBuilder($r('app.media.tz_sl'),$r('app.media.tz'),'投资',8)
                this.iconBuilder($r('app.media.gw_sl'),$r('app.media.gw'),'购物',9)
                this.iconBuilder($r('app.media.yule_sl'),$r('app.media.yule'),'娱乐',10)
                this.iconBuilder($r('app.media.zz_sl'),$r('app.media.zz'),'外借',11)
              }.justifyContent(FlexAlign.SpaceAround)
              .padding(10)
              .width('100%')
              Row() {
                this.iconBuilder($r('app.media.other_sl'),$r('app.media.other'),'其他',12)
              }
              .padding(10)
              .width('93%')

              // 日期、备注信息
              Row(){
                CalendarPicker({ hintRadius: 10, selected: this.selectedDate })
                  .width('30%')
                  .width('25%')
                  .edgeAlign(CalendarAlign.CENTER,{dx:1,dy:1})
                  .textStyle({ color:Color.Black,font:{ size:15,weight:FontWeight.Normal } })
                  .onChange((date: Date) => {
                    this.selectedDate = date;
                  })

                TextInput({placeholder:'请输入备注', text: this.note})
                  .backgroundColor('#f0f0f0')
                  .width('50%')
                  .height('56%')
                  .borderRadius(10)
                  .onChange((value: string) => {
                    this.note = value;
                  })
              }
              .width('90%')
              .height('12%')
              .margin({top:10})
              .borderWidth({top:1,bottom:1})
              .borderColor('#bfbfbf')

            }.width('88%')
            .height('80%')
            .backgroundColor('#f0f0f0')
            .borderRadius(30)
            .padding(10)


            Row() {
              Button('保存').backgroundColor(Color.Black).margin({right:4}).width('85%')
                .onClick(async () => {
                  const result = await this.saveExpenseBill();
                  if (result.success) {
                    this.handlePopup1 = true;
                    // 重置表单
                    this.amount = '';
                    this.note = '';
                    this.selectedDate = new Date();
                    this.iconCurrentIndex = 0;
                  } else {
                    promptAction.showToast({
                      message: result.message,
                      duration: 2000
                    });
                  }
                })
                .bindPopup(this.handlePopup1, {
                  builder: this.popupWithButtonBuilder1(),
                  placement: Placement.Top,
                  width: '315vp',
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.handlePopup1 = false;
                    }
                  }
                })
            }.margin({top:20})

          }.height('100%')
          .width('100%')

        }.tabBar(this.tabBuilder('支出',0))
        .margin({top:5})

        ////////////////////////////////////////////////////////////////////////////////////////////////////
        // 收入页
        TabContent(){
          Column(){
            Column(){

              // 账单金额输入栏
              Row(){
                Text('账单金额:').fontSize(18)
                TextInput({placeholder:'￥0.00', text: this.amount})
                  .width('35%')
                  .backgroundColor('#f0f0f0')
                  .onChange((value: string) => {
                    this.amount = value;
                  })
              }.width('90%')
              .height('10%')
              .borderWidth({bottom:1})
              .borderColor('#bfbfbf')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({bottom:5})

              // 收入类别图标实现
              Row() {
                this.iconBuilder($r('app.media.gz_sl'),$r('app.media.gz'),'工资',13)
                this.iconBuilder($r('app.media.jj_sl'),$r('app.media.jj'),'奖金',14)
                this.iconBuilder($r('app.media.tz_sl'),$r('app.media.tz'),'投资',15)
                this.iconBuilder($r('app.media.zj_sl'),$r('app.media.zj'),'租金',16)
              }.justifyContent(FlexAlign.SpaceAround)
              .padding(10)
              .width('100%')
              Row() {
                this.iconBuilder($r('app.media.bx_sl'),$r('app.media.bx'),'报销',17)
                this.iconBuilder($r('app.media.tk_sl'),$r('app.media.tk'),'退款',18)
                this.iconBuilder($r('app.media.hb_sl'),$r('app.media.hb'),'红包',19)
                this.iconBuilder($r('app.media.lx_sl'),$r('app.media.lx'),'利息',20)
              }.justifyContent(FlexAlign.SpaceAround)
              .padding(10)
              .width('100%')
              Row() {
                this.iconBuilder($r('app.media.jy_sl'),$r('app.media.jy'),'交易',21)
                this.iconBuilder($r('app.media.jxj_sl'),$r('app.media.jxj'),'奖学金',22)
                this.iconBuilder($r('app.media.fh_sl'),$r('app.media.fh'),'分红',23)
                this.iconBuilder($r('app.media.other_sl'),$r('app.media.other'),'其他',24)
              }.justifyContent(FlexAlign.SpaceAround)
              .padding(10)
              .width('100%')
              .margin({bottom:85})

              // 日期、备注信息
              Row(){
                CalendarPicker({ hintRadius: 10, selected: this.selectedDate })
                  .width('30%')
                  .width('25%')
                  .edgeAlign(CalendarAlign.CENTER,{dx:1,dy:1})
                  .textStyle({ color:Color.Black,font:{ size:15,weight:FontWeight.Normal } })
                  .onChange((date: Date) => {
                    this.selectedDate = date;
                  })

                TextInput({placeholder:'请输入备注', text: this.note})
                  .backgroundColor('#f0f0f0')
                  .width('50%')
                  .height('56%')
                  .borderRadius(10)
                  .onChange((value: string) => {
                    this.note = value;
                  })
              }
              .width('90%')
              .height('12%')
              .margin({top:10})
              .borderWidth({top:1,bottom:1})
              .borderColor('#bfbfbf')

            }.width('88%')
            .height('80%')
            .backgroundColor('#f0f0f0')
            .borderRadius(30)
            .padding(10)

            // 保存、再记一笔按键
            Row() {
              Button('保存').backgroundColor(Color.Black).margin({right:4}).width('80%')
                .onClick(async () => {
                  const result = await this.saveIncomeBill();
                  if (result.success) {
                    this.handlePopup2 = true;
                    // 重置表单
                    this.amount = '';
                    this.note = '';
                    this.selectedDate = new Date();
                    this.iconCurrentIndex = 13; // 重置为收入的第一个图标
                  } else {
                    promptAction.showToast({
                      message: result.message,
                      duration: 2000
                    });
                  }
                })
                .bindPopup(this.handlePopup2, {
                  builder: this.popupWithButtonBuilder2(),
                  placement: Placement.Top,
                  width: '315vp',
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.handlePopup2 = false;
                    }
                  }
                })
            }.margin({top:20})

          }.height('100%')
          .width('100%')

        }.tabBar(this.tabBuilder('收入',1))
        .margin({top:5})

      }.onChange((index: number) => {
        this.currentIndex = index;
        // 根据当前选项卡重置图标索引
        this.iconCurrentIndex = index === 0 ? 0 : 13; // 支出从0开始，收入从13开始
      })
    }
  }
}